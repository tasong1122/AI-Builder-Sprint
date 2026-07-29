import 'package:cloud_firestore/cloud_firestore.dart';

enum ContractStatus { editing, waitingAgreement, active }

extension ContractStatusValue on ContractStatus {
  String get firestoreValue {
    return switch (this) {
      ContractStatus.editing => 'editing',
      ContractStatus.waitingAgreement => 'waiting_agreement',
      ContractStatus.active => 'active',
    };
  }

  String get displayName {
    return switch (this) {
      ContractStatus.editing => '편집중',
      ContractStatus.waitingAgreement => '확인 대기중',
      ContractStatus.active => '진행중',
    };
  }
}

class ContractModel {
  const ContractModel({
    required this.id,
    required this.lenderUid,
    required this.lenderName,
    required this.borrowerUid,
    required this.borrowerName,
    required this.creatorUid,
    required this.principalAmount,
    required this.interestRate,
    required this.interestAmount,
    required this.totalRepaymentAmount,
    required this.dueDate,
    required this.lenderAgreed,
    required this.borrowerAgreed,
    required this.status,
    required this.memo,
  });

  final String id;
  final String? lenderUid;
  final String lenderName;
  final String? borrowerUid;
  final String borrowerName;
  final String creatorUid;
  final int principalAmount;
  final double interestRate;
  final int interestAmount;
  final int totalRepaymentAmount;
  final DateTime dueDate;
  final bool lenderAgreed;
  final bool borrowerAgreed;
  final ContractStatus status;
  final String memo;

  // Firestore 계약 문서를 앱에서 사용하는 모델로 변환한다.
  factory ContractModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw const FormatException('돈 약속을 찾을 수 없습니다.');
    }

    return ContractModel(
      id: document.id,
      lenderUid: _readNullableString(data, 'lender_uid'),
      lenderName: _readRequiredString(data, 'lender_name'),
      borrowerUid: _readNullableString(data, 'borrower_uid'),
      borrowerName: _readRequiredString(data, 'borrower_name'),
      creatorUid: _readRequiredString(data, 'creator_uid'),
      principalAmount: _readNonNegativeInt(data, 'principal_amount'),
      interestRate: _readNonNegativeDouble(data, 'interest_rate'),
      interestAmount: _readNonNegativeInt(data, 'interest_amount'),
      totalRepaymentAmount: _readNonNegativeInt(data, 'total_repayment_amount'),
      dueDate: _readTimestamp(data, 'due_date').toDate(),
      lenderAgreed: _readBool(data, 'lender_agreed'),
      borrowerAgreed: _readBool(data, 'borrower_agreed'),
      status: _readStatus(data['status']),
      memo: _readMemo(data['memo']),
    )..validate();
  }

  // 계약 모델을 DATA_STRUCTURE.md에 정의된 Firestore 형식으로 변환한다.
  Map<String, dynamic> toFirestore() {
    validate();

    return {
      'lender_uid': lenderUid,
      'lender_name': lenderName.trim(),
      'borrower_uid': borrowerUid,
      'borrower_name': borrowerName.trim(),
      'creator_uid': creatorUid,
      'principal_amount': principalAmount,
      'interest_rate': interestRate,
      'interest_amount': interestAmount,
      'total_repayment_amount': totalRepaymentAmount,
      'due_date': Timestamp.fromDate(dueDate),
      'lender_agreed': lenderAgreed,
      'borrower_agreed': borrowerAgreed,
      'status': status.firestoreValue,
      'memo': memo.trim(),
    };
  }

  // 계약 금액과 당사자 정보가 데이터 규칙에 맞는지 확인한다.
  void validate() {
    if (principalAmount <= 0) {
      throw const FormatException('빌릴 금액은 0원보다 커야 합니다.');
    }
    if (interestRate < 0 || interestAmount < 0) {
      throw const FormatException('이자율과 이자 금액은 음수일 수 없습니다.');
    }
    if (totalRepaymentAmount != principalAmount + interestAmount) {
      throw const FormatException('총 갚을 금액이 올바르지 않습니다.');
    }
    if (lenderName.trim().isEmpty || borrowerName.trim().isEmpty) {
      throw const FormatException('돈 약속에 참여하는 사람의 이름이 필요합니다.');
    }
    if (creatorUid.trim().isEmpty) {
      throw const FormatException('돈 약속을 만든 사람의 정보가 필요합니다.');
    }
    if (lenderUid != null && lenderUid == borrowerUid) {
      throw const FormatException('같은 사용자끼리는 돈 약속을 만들 수 없습니다.');
    }
  }

  // 현재 사용자 UID를 기준으로 계약 상대방 이름을 반환한다.
  String otherPartyName(String currentUserUid) {
    if (currentUserUid == lenderUid) {
      return borrowerName;
    }
    if (currentUserUid == borrowerUid) {
      if (lenderUid == null && status == ContractStatus.waitingAgreement) {
        return '대기중';
      }
      return lenderName;
    }
    return '알 수 없는 사용자';
  }

  // 현재 사용자가 계약에서 빌리는 사람인지 확인한다.
  bool isBorrower(String currentUserUid) => borrowerUid == currentUserUid;

  // 현재 사용자가 계약에서 빌려주는 사람인지 확인한다.
  bool isLender(String currentUserUid) => lenderUid == currentUserUid;

  // 모델의 일부 값만 바꾼 새 계약 모델을 생성한다.
  ContractModel copyWith({
    String? id,
    String? lenderUid,
    bool clearLenderUid = false,
    String? lenderName,
    String? borrowerUid,
    bool clearBorrowerUid = false,
    String? borrowerName,
    String? creatorUid,
    int? principalAmount,
    double? interestRate,
    int? interestAmount,
    int? totalRepaymentAmount,
    DateTime? dueDate,
    bool? lenderAgreed,
    bool? borrowerAgreed,
    ContractStatus? status,
    String? memo,
  }) {
    return ContractModel(
      id: id ?? this.id,
      lenderUid: clearLenderUid ? null : lenderUid ?? this.lenderUid,
      lenderName: lenderName ?? this.lenderName,
      borrowerUid: clearBorrowerUid ? null : borrowerUid ?? this.borrowerUid,
      borrowerName: borrowerName ?? this.borrowerName,
      creatorUid: creatorUid ?? this.creatorUid,
      principalAmount: principalAmount ?? this.principalAmount,
      interestRate: interestRate ?? this.interestRate,
      interestAmount: interestAmount ?? this.interestAmount,
      totalRepaymentAmount: totalRepaymentAmount ?? this.totalRepaymentAmount,
      dueDate: dueDate ?? this.dueDate,
      lenderAgreed: lenderAgreed ?? this.lenderAgreed,
      borrowerAgreed: borrowerAgreed ?? this.borrowerAgreed,
      status: status ?? this.status,
      memo: memo ?? this.memo,
    );
  }

  static ContractStatus _readStatus(Object? value) {
    return switch (value) {
      'editing' => ContractStatus.editing,
      'waiting_agreement' => ContractStatus.waitingAgreement,
      'active' => ContractStatus.active,
      _ => throw const FormatException('돈 약속 상태가 올바르지 않습니다.'),
    };
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

  static String? _readNullableString(
    Map<String, dynamic> data,
    String fieldName,
  ) {
    final value = data[fieldName];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value.trim();
  }

  static int _readNonNegativeInt(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value is! num || value < 0 || value != value.roundToDouble()) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value.toInt();
  }

  static double _readNonNegativeDouble(
    Map<String, dynamic> data,
    String fieldName,
  ) {
    final value = data[fieldName];
    if (value is! num || value < 0) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value.toDouble();
  }

  static Timestamp _readTimestamp(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value is! Timestamp) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value;
  }

  static bool _readBool(Map<String, dynamic> data, String fieldName) {
    final value = data[fieldName];
    if (value is! bool) {
      throw FormatException('$fieldName 필드가 올바르지 않습니다.');
    }
    return value;
  }

  static String _readMemo(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is! String) {
      throw const FormatException('memo 필드가 올바르지 않습니다.');
    }
    return value.trim();
  }
}
