import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/contract_model.dart';
import '../models/user_model.dart';

class ContractService {
  ContractService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _contracts =>
      _firestore.collection('contracts');

  // 계약 ID로 계약 문서를 불러온다.
  Future<ContractModel> getContract(String contractId) async {
    final currentUserUid = _requireCurrentUserUid();
    final document = await _contracts.doc(contractId).get();
    final contract = ContractModel.fromDocument(document);
    _ensureParticipant(contract, currentUserUid);
    return contract;
  }

  // 계약 ID로 계약 문서의 실시간 변경을 전달한다.
  Stream<ContractModel> watchContract(String contractId) {
    final currentUserUid = _requireCurrentUserUid();
    return _contracts.doc(contractId).snapshots().map((document) {
      final contract = ContractModel.fromDocument(document);
      _ensureParticipant(contract, currentUserUid);
      return contract;
    });
  }

  // 사용자 문서의 연결 ID를 기준으로 숨기지 않은 계약 목록을 불러온다.
  Future<List<ContractModel>> getCurrentUserContracts({
    bool activeOnly = false,
  }) async {
    final currentUserUid = _requireCurrentUserUid();
    final userDocument = await _users.doc(currentUserUid).get();
    final user = UserModel.fromDocument(userDocument);

    final visibleIds = user.activeContractIds
        .where((id) => !user.hiddenContractIds.contains(id))
        .toList();

    final documents = await Future.wait(
      visibleIds.map((id) => _contracts.doc(id).get()),
    );
    final missingIds = <String>[];
    final contracts = <ContractModel>[];

    for (final document in documents) {
      if (!document.exists) {
        missingIds.add(document.id);
        continue;
      }

      final contract = ContractModel.fromDocument(document);
      if (!contract.isBorrower(currentUserUid) &&
          !contract.isLender(currentUserUid)) {
        missingIds.add(document.id);
        continue;
      }
      if (!activeOnly || contract.status == ContractStatus.active) {
        contracts.add(contract);
      }
    }

    if (missingIds.isNotEmpty) {
      await _users.doc(currentUserUid).update({
        'active_contract_ids': FieldValue.arrayRemove(missingIds),
        'hidden_contract_ids': FieldValue.arrayRemove(missingIds),
      });
    }

    contracts.sort((first, second) => first.dueDate.compareTo(second.dueDate));
    return contracts;
  }

  // editing 계약과 작성자의 계약 ID 연결을 batch로 함께 생성한다.
  Future<String> createContract(ContractModel contract) async {
    final currentUserUid = _requireCurrentUserUid();
    if (contract.creatorUid != currentUserUid) {
      throw StateError('현재 사용자만 돈 약속을 만들 수 있습니다.');
    }
    if (!contract.isBorrower(currentUserUid) &&
        !contract.isLender(currentUserUid)) {
      throw StateError('돈 약속을 만든 사람도 약속에 참여해야 합니다.');
    }

    final contractReference = _contracts.doc();
    final editingContract = contract.copyWith(
      id: contractReference.id,
      lenderAgreed: false,
      borrowerAgreed: false,
      status: ContractStatus.editing,
    );
    editingContract.validate();

    final batch = _firestore.batch();
    batch.set(contractReference, editingContract.toFirestore());
    batch.update(_users.doc(currentUserUid), {
      'active_contract_ids': FieldValue.arrayUnion([contractReference.id]),
    });
    await batch.commit();

    return contractReference.id;
  }

  // 작성자가 기존 editing 계약의 내용만 갱신한다.
  Future<void> updateEditingContract(ContractModel updatedContract) async {
    final currentUserUid = _requireCurrentUserUid();
    final contractReference = _contracts.doc(updatedContract.id);

    await _firestore.runTransaction((transaction) async {
      final document = await transaction.get(contractReference);
      final currentContract = ContractModel.fromDocument(document);

      if (currentContract.creatorUid != currentUserUid) {
        throw StateError('돈 약속을 만든 사람만 수정할 수 있습니다.');
      }
      if (currentContract.status != ContractStatus.editing) {
        throw StateError('작성 중인 돈 약속만 수정할 수 있습니다.');
      }
      if (updatedContract.creatorUid != currentContract.creatorUid ||
          updatedContract.lenderUid != currentContract.lenderUid ||
          updatedContract.borrowerUid != currentContract.borrowerUid) {
        throw StateError('돈 약속에 참여한 사람은 변경할 수 없습니다.');
      }

      final editingContract = updatedContract.copyWith(
        lenderAgreed: false,
        borrowerAgreed: false,
        status: ContractStatus.editing,
      );
      transaction.set(contractReference, editingContract.toFirestore());
    });
  }

  // 작성이 끝난 계약을 상대방 동의 대기 상태로 변경한다.
  Future<void> sendContract(String contractId) async {
    final currentUserUid = _requireCurrentUserUid();
    final contractReference = _contracts.doc(contractId);

    await _firestore.runTransaction((transaction) async {
      final document = await transaction.get(contractReference);
      final contract = ContractModel.fromDocument(document);

      if (contract.creatorUid != currentUserUid) {
        throw StateError('돈 약속을 만든 사람만 보낼 수 있습니다.');
      }
      if (contract.status != ContractStatus.editing) {
        throw StateError('작성 중인 돈 약속만 보낼 수 있습니다.');
      }
      if (!contract.isBorrower(currentUserUid)) {
        throw StateError('돈을 빌리는 사람만 약속을 보낼 수 있습니다.');
      }

      transaction.update(contractReference, {
        'borrower_agreed': true,
        'status': ContractStatus.waitingAgreement.firestoreValue,
      });
    });
  }

  // 공유 링크로 접속한 사용자를 비어 있는 계약 역할에 연결한다.
  Future<void> joinContract(String contractId) async {
    final currentUserUid = _requireCurrentUserUid();
    final contractReference = _contracts.doc(contractId);
    final userReference = _users.doc(currentUserUid);

    await _firestore.runTransaction((transaction) async {
      final contractDocument = await transaction.get(contractReference);
      final userDocument = await transaction.get(userReference);
      final contract = ContractModel.fromDocument(contractDocument);
      final user = UserModel.fromDocument(userDocument);

      if (contract.status != ContractStatus.waitingAgreement) {
        throw StateError('확인을 기다리는 돈 약속에만 참여할 수 있습니다.');
      }
      if (contract.isBorrower(currentUserUid) ||
          contract.isLender(currentUserUid)) {
        transaction.update(userReference, {
          'active_contract_ids': FieldValue.arrayUnion([contractId]),
        });
        return;
      }

      if (contract.lenderUid == null &&
          contract.borrowerUid != currentUserUid) {
        transaction.update(contractReference, {
          'lender_uid': currentUserUid,
          'lender_name': user.name,
        });
      } else if (contract.borrowerUid == null &&
          contract.lenderUid != currentUserUid) {
        transaction.update(contractReference, {
          'borrower_uid': currentUserUid,
          'borrower_name': user.name,
        });
      } else {
        throw StateError('이 돈 약속에는 참여할 수 없습니다.');
      }

      transaction.update(userReference, {
        'active_contract_ids': FieldValue.arrayUnion([contractId]),
      });
    });
  }

  // 현재 사용자의 동의만 변경하고 양쪽 동의가 완료되면 계약을 활성화한다.
  Future<void> agreeToContract(String contractId) async {
    final currentUserUid = _requireCurrentUserUid();
    final contractReference = _contracts.doc(contractId);

    await _firestore.runTransaction((transaction) async {
      final contractDocument = await transaction.get(contractReference);
      final contract = ContractModel.fromDocument(contractDocument);

      if (contract.status != ContractStatus.waitingAgreement) {
        throw StateError('확인을 기다리는 돈 약속만 확인할 수 있습니다.');
      }

      final isLender = contract.isLender(currentUserUid);
      final isBorrower = contract.isBorrower(currentUserUid);
      if (!isLender && !isBorrower) {
        throw StateError('돈 약속에 참여한 사람만 확인할 수 있습니다.');
      }

      final lenderAgreed = isLender ? true : contract.lenderAgreed;
      final borrowerAgreed = isBorrower ? true : contract.borrowerAgreed;
      final shouldActivate = lenderAgreed && borrowerAgreed;

      DocumentSnapshot<Map<String, dynamic>>? lenderDocument;
      DocumentSnapshot<Map<String, dynamic>>? borrowerDocument;
      if (shouldActivate) {
        final lenderUid = contract.lenderUid;
        final borrowerUid = contract.borrowerUid;
        if (lenderUid == null || borrowerUid == null) {
          throw StateError('돈 약속에 참여할 사람의 연결이 끝나지 않았습니다.');
        }
        lenderDocument = await transaction.get(_users.doc(lenderUid));
        borrowerDocument = await transaction.get(_users.doc(borrowerUid));
      }

      transaction.update(contractReference, {
        if (isLender) 'lender_agreed': true,
        if (isBorrower) 'borrower_agreed': true,
        'status': shouldActivate
            ? ContractStatus.active.firestoreValue
            : ContractStatus.waitingAgreement.firestoreValue,
      });

      if (shouldActivate) {
        final lender = UserModel.fromDocument(lenderDocument!);
        final borrower = UserModel.fromDocument(borrowerDocument!);
        transaction.update(_users.doc(lender.uid), {
          'lent_total': lender.lentTotal + contract.totalRepaymentAmount,
          'active_contract_ids': FieldValue.arrayUnion([contractId]),
        });
        transaction.update(_users.doc(borrower.uid), {
          'borrowed_total':
              borrower.borrowedTotal + contract.totalRepaymentAmount,
          'active_contract_ids': FieldValue.arrayUnion([contractId]),
        });
      }
    });
  }

  // 작성자가 editing 또는 waiting 계약과 연결 ID를 함께 삭제한다.
  Future<void> deletePendingContract(String contractId) async {
    final currentUserUid = _requireCurrentUserUid();
    final contractReference = _contracts.doc(contractId);

    await _firestore.runTransaction((transaction) async {
      final contractDocument = await transaction.get(contractReference);
      final contract = ContractModel.fromDocument(contractDocument);

      if (contract.creatorUid != currentUserUid) {
        throw StateError('돈 약속을 만든 사람만 삭제할 수 있습니다.');
      }
      if (contract.status == ContractStatus.active) {
        throw StateError('진행 중인 돈 약속은 삭제할 수 없습니다.');
      }

      final participantUids = {
        if (contract.lenderUid != null) contract.lenderUid!,
        if (contract.borrowerUid != null) contract.borrowerUid!,
      };
      final userDocuments = await Future.wait(
        participantUids.map((uid) => transaction.get(_users.doc(uid))),
      );

      for (final userDocument in userDocuments) {
        if (!userDocument.exists) {
          continue;
        }
        transaction.update(userDocument.reference, {
          'active_contract_ids': FieldValue.arrayRemove([contractId]),
          'hidden_contract_ids': FieldValue.arrayRemove([contractId]),
        });
      }
      transaction.delete(contractReference);
    });
  }

  // active 계약을 현재 사용자의 목록에서만 숨긴다.
  Future<void> hideActiveContract(String contractId) async {
    final currentUserUid = _requireCurrentUserUid();
    final contract = await getContract(contractId);
    if (contract.status != ContractStatus.active) {
      throw StateError('진행 중인 돈 약속만 가릴 수 있습니다.');
    }

    await _users.doc(currentUserUid).update({
      'hidden_contract_ids': FieldValue.arrayUnion([contractId]),
    });
  }

  // borrower의 상환 완료 처리와 양쪽 사용자 데이터 정리를 transaction으로 수행한다.
  Future<void> completeRepayment(String contractId) async {
    final currentUserUid = _requireCurrentUserUid();
    final contractReference = _contracts.doc(contractId);

    await _firestore.runTransaction((transaction) async {
      final contractDocument = await transaction.get(contractReference);
      final contract = ContractModel.fromDocument(contractDocument);

      if (contract.status != ContractStatus.active) {
        throw StateError('진행 중인 돈 약속만 갚을 수 있습니다.');
      }
      if (!contract.isBorrower(currentUserUid)) {
        throw StateError('돈을 빌린 사람만 갚기를 완료할 수 있습니다.');
      }

      final lenderUid = contract.lenderUid;
      final borrowerUid = contract.borrowerUid;
      if (lenderUid == null || borrowerUid == null) {
        throw StateError('돈 약속에 참여한 사람의 정보가 올바르지 않습니다.');
      }

      final lenderDocument = await transaction.get(_users.doc(lenderUid));
      final borrowerDocument = await transaction.get(_users.doc(borrowerUid));
      final lender = UserModel.fromDocument(lenderDocument);
      final borrower = UserModel.fromDocument(borrowerDocument);

      transaction.update(_users.doc(lenderUid), {
        'lent_total': math.max(
          0,
          lender.lentTotal - contract.totalRepaymentAmount,
        ),
        'active_contract_ids': FieldValue.arrayRemove([contractId]),
        'hidden_contract_ids': FieldValue.arrayRemove([contractId]),
      });
      transaction.update(_users.doc(borrowerUid), {
        'borrowed_total': math.max(
          0,
          borrower.borrowedTotal - contract.totalRepaymentAmount,
        ),
        'active_contract_ids': FieldValue.arrayRemove([contractId]),
        'hidden_contract_ids': FieldValue.arrayRemove([contractId]),
      });
      transaction.delete(contractReference);
    });
  }

  // 인증이 필요한 계약 작업에서 현재 UID를 반환한다.
  String _requireCurrentUserUid() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }
    return user.uid;
  }

  // 현재 사용자가 계약 당사자인지 확인한다.
  void _ensureParticipant(ContractModel contract, String currentUserUid) {
    if (!contract.isBorrower(currentUserUid) &&
        !contract.isLender(currentUserUid)) {
      throw StateError('이 돈 약속을 확인할 수 없습니다.');
    }
  }
}
