import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderNotificationModel {
  const ReminderNotificationModel({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.contractId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String senderUid;
  final String senderName;
  final String contractId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  // 알림 문서를 화면에서 안전하게 사용할 수 있는 모델로 변환한다.
  factory ReminderNotificationModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw const FormatException('알림 문서가 존재하지 않습니다.');
    }

    return ReminderNotificationModel(
      id: document.id,
      senderUid: _readRequiredString(data, 'sender_uid'),
      senderName: _readRequiredString(data, 'sender_name'),
      contractId: _readRequiredString(data, 'contract_id'),
      message: _readRequiredString(data, 'message'),
      isRead: _readRequiredBool(data, 'is_read'),
      createdAt: _readTimestamp(data, 'created_at').toDate(),
    );
  }

  static String _readRequiredString(
    Map<String, dynamic> data,
    String fieldName,
  ) {
    final value = data[fieldName];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value.trim();
  }

  static bool _readRequiredBool(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value is! bool) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value;
  }

  static Timestamp _readTimestamp(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value is! Timestamp) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value;
  }
}
