import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // 이메일과 비밀번호로 로그인한다.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const FormatException('이메일과 비밀번호를 입력해 주세요.');
    }

    return _firebaseAuth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
  }

  // Firebase 계정과 초기 Firestore 사용자 문서를 함께 생성한다.
  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();

    if (normalizedName.isEmpty) {
      throw const FormatException('사용자 이름을 입력해 주세요.');
    }
    if (normalizedEmail.isEmpty) {
      throw const FormatException('이메일을 입력해 주세요.');
    }
    if (password.isEmpty || password != passwordConfirmation) {
      throw const FormatException('비밀번호 확인 값이 일치하지 않습니다.');
    }

    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('생성된 사용자 정보를 확인할 수 없습니다.');
    }

    final userModel = UserModel(
      uid: user.uid,
      name: normalizedName,
      email: normalizedEmail,
      borrowedTotal: 0,
      lentTotal: 0,
      activeContractIds: const [],
      hiddenContractIds: const [],
    );

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore());
      return credential;
    } catch (_) {
      try {
        await user.delete();
      } catch (_) {
        await _firebaseAuth.signOut();
      }
      rethrow;
    }
  }

  // 현재 로그인한 사용자의 Firestore 프로필을 불러온다.
  Future<UserModel> getCurrentUserProfile() async {
    final user = _requireCurrentUser();
    final document = await _firestore.collection('users').doc(user.uid).get();
    return UserModel.fromDocument(document);
  }

  // 현재 로그인한 사용자의 프로필 변경을 실시간으로 전달한다.
  Stream<UserModel> watchCurrentUserProfile() {
    final user = _requireCurrentUser();
    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map(UserModel.fromDocument);
  }

  // 현재 Firebase 인증 세션에서 로그아웃한다.
  Future<void> signOut() => _firebaseAuth.signOut();

  // 현재 로그인 이메일로 비밀번호 재설정 링크를 발송한다.
  Future<void> sendPasswordResetEmail() async {
    final email = _requireCurrentUser().email;
    if (email == null || email.isEmpty) {
      throw StateError('계정 이메일을 확인할 수 없습니다.');
    }
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // 인증이 필요한 작업에서 현재 사용자를 확인한다.
  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user;
  }
}
