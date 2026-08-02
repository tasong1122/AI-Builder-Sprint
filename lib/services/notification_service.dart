import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/reminder_notification_model.dart';

class NotificationService {
  NotificationService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notifications(String uid) {
    return _firestore.collection('users').doc(uid).collection('notifications');
  }

  // 현재 사용자의 미읽음 알림 여부를 실시간으로 전달한다.
  Stream<bool> watchHasUnreadNotifications() {
    final currentUserUid = _requireCurrentUserUid();
    return _notifications(currentUserUid)
        .where('is_read', isEqualTo: false)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  // 현재 사용자의 알림 목록을 최신순으로 전달한다.
  Stream<List<ReminderNotificationModel>> watchCurrentUserNotifications({
    int limit = 30,
  }) {
    final currentUserUid = _requireCurrentUserUid();
    return _notifications(currentUserUid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(ReminderNotificationModel.fromDocument)
              .toList(growable: false),
        );
  }

  // 현재 사용자의 모든 미읽음 알림을 읽음 상태로 변경한다.
  Future<void> markAllAsRead() async {
    final currentUserUid = _requireCurrentUserUid();
    final querySnapshot = await _notifications(
      currentUserUid,
    ).where('is_read', isEqualTo: false).get();

    if (querySnapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final document in querySnapshot.docs) {
      batch.update(document.reference, {'is_read': true});
    }
    await batch.commit();
  }

  // 상대방 사용자에게 독촉문자 알림을 저장한다.
  Future<void> sendReminderNotification({
    required String recipientUid,
    required String senderUid,
    required String senderName,
    required String contractId,
    required String message,
  }) async {
    final normalizedMessage = message.trim();
    final normalizedSenderName = senderName.trim();

    if (recipientUid.trim().isEmpty ||
        senderUid.trim().isEmpty ||
        normalizedSenderName.isEmpty ||
        contractId.trim().isEmpty ||
        normalizedMessage.isEmpty) {
      throw const FormatException('알림을 보내기 위한 정보가 올바르지 않습니다.');
    }

    await _notifications(recipientUid).add({
      'sender_uid': senderUid,
      'sender_name': normalizedSenderName,
      'contract_id': contractId,
      'message': normalizedMessage,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // 인증이 필요한 알림 작업에서 현재 UID를 반환한다.
  String _requireCurrentUserUid() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user.uid;
  }
}
