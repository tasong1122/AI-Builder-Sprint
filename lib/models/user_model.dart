import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.borrowedTotal,
    required this.lentTotal,
    required this.activeContractIds,
    required this.hiddenContractIds,
  });

  final String uid;
  final String name;
  final String email;
  final int borrowedTotal;
  final int lentTotal;
  final List<String> activeContractIds;
  final List<String> hiddenContractIds;

  // Firestore 사용자 문서를 앱에서 사용하는 모델로 변환한다.
  factory UserModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw const FormatException('사용자 문서가 존재하지 않습니다.');
    }

    return UserModel(
      uid: document.id,
      name: _readRequiredString(data, 'name'),
      email: _readRequiredString(data, 'email'),
      borrowedTotal: _readNonNegativeInt(data, 'borrowed_total'),
      lentTotal: _readNonNegativeInt(data, 'lent_total'),
      activeContractIds: _readStringList(data, 'active_contract_ids'),
      hiddenContractIds: _readStringList(data, 'hidden_contract_ids'),
    );
  }

  // 회원가입 시 저장할 초기 사용자 데이터를 Firestore 형식으로 반환한다.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      'email': email.trim(),
      'borrowed_total': borrowedTotal,
      'lent_total': lentTotal,
      'active_contract_ids': activeContractIds,
      'hidden_contract_ids': hiddenContractIds,
    };
  }

  // 모델의 일부 값만 바꾼 새 사용자 모델을 생성한다.
  UserModel copyWith({
    String? name,
    String? email,
    int? borrowedTotal,
    int? lentTotal,
    List<String>? activeContractIds,
    List<String>? hiddenContractIds,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      borrowedTotal: borrowedTotal ?? this.borrowedTotal,
      lentTotal: lentTotal ?? this.lentTotal,
      activeContractIds: activeContractIds ?? this.activeContractIds,
      hiddenContractIds: hiddenContractIds ?? this.hiddenContractIds,
    );
  }

  // 필수 문자열 필드를 안전하게 읽고 잘못된 문서는 명확히 거부한다.
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

  // 숫자 필드를 음수가 아닌 정수로 검증해 읽는다.
  static int _readNonNegativeInt(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value is! num || value < 0 || value != value.roundToDouble()) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value.toInt();
  }

  // 문자열 배열 필드를 타입이 안전한 새 목록으로 변환한다.
  static List<String> _readStringList(
    Map<String, dynamic> data,
    String fieldName,
  ) {
    final value = data[fieldName];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }
}
