import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../models/contract_model.dart';
import '../../services/auth_service.dart';
import '../../services/contract_service.dart';
import '../../widgets/contract_card.dart';
import 'create_contract_screen.dart';
import 'detail_contract_screen.dart';

class ContractListScreen extends StatefulWidget {
  const ContractListScreen({super.key});

  @override
  State<ContractListScreen> createState() => ContractListScreenState();
}

class ContractListScreenState extends State<ContractListScreen> {
  List<ContractModel> contracts = const [];
  String? currentUserUid;
  String? errorMessage;
  bool isLoading = true;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    loadContracts();
  }

  // 현재 사용자의 hidden_contract_ids를 제외한 계약 목록을 불러온다.
  Future<void> loadContracts() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final authService = AuthService();
      final uid = authService.currentUser?.uid;
      if (uid == null) {
        throw StateError('로그인이 필요합니다.');
      }

      final visibleContracts = await ContractService()
          .getCurrentUserContracts();
      if (!mounted) {
        return;
      }
      setState(() {
        currentUserUid = uid;
        contracts = visibleContracts;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
        errorMessage = '돈 약속 목록을 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.';
      });
    }
  }

  // 새 계약 작성 화면을 열고 돌아오면 계약 목록을 새로 불러온다.
  Future<void> openCreateContractScreen({String? contractId}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CreateContractScreen(contractId: contractId),
      ),
    );
    if (changed == true && mounted) {
      await loadContracts();
    }
  }

  // 계약 상태에 따라 편집 화면 또는 읽기 전용 상세 화면을 연다.
  Future<void> openContract(ContractModel contract) async {
    if (contract.status == ContractStatus.editing) {
      await openCreateContractScreen(contractId: contract.id);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DetailContractScreen(contractId: contract.id),
      ),
    );
    if (changed == true && mounted) {
      await loadContracts();
    }
  }

  // 계약 상태와 작성자 권한에 맞는 삭제 또는 가리기 메뉴를 표시한다.
  Future<void> showContractActions(ContractModel contract) async {
    final uid = currentUserUid;
    if (uid == null || isProcessing) {
      return;
    }

    if (contract.status == ContractStatus.active) {
      final shouldHide = await _showConfirmationDialog(
        title: '돈 약속 가리기',
        message: '이 돈 약속을 내 목록에서 가리시겠습니까?\n상대방의 목록에는 계속 표시됩니다.',
        confirmLabel: '가리기',
      );
      if (shouldHide) {
        await hideContract(contract.id);
      }
      return;
    }

    if (contract.creatorUid != uid) {
      _showMessage('돈 약속을 만든 사람만 삭제할 수 있습니다.');
      return;
    }
    final shouldDelete = await _showConfirmationDialog(
      title: '돈 약속 삭제',
      message: '이 돈 약속을 삭제하시겠습니까?\n삭제한 돈 약속은 복구할 수 없습니다.',
      confirmLabel: '삭제',
    );
    if (shouldDelete) {
      await deleteContract(contract.id);
    }
  }

  // active 계약 ID를 현재 사용자의 hidden_contract_ids에 추가한다.
  Future<void> hideContract(String contractId) async {
    setState(() {
      isProcessing = true;
    });
    try {
      await ContractService().hideActiveContract(contractId);
      if (!mounted) {
        return;
      }
      setState(() {
        contracts = contracts
            .where((contract) => contract.id != contractId)
            .toList(growable: false);
      });
      _showMessage('돈 약속을 내 목록에서 가렸습니다.');
    } catch (_) {
      if (mounted) {
        _showMessage('돈 약속을 가리지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // 작성자가 editing 또는 waiting 계약을 양쪽 사용자 연결 목록과 함께 삭제한다.
  Future<void> deleteContract(String contractId) async {
    setState(() {
      isProcessing = true;
    });
    try {
      await ContractService().deletePendingContract(contractId);
      if (!mounted) {
        return;
      }
      setState(() {
        contracts = contracts
            .where((contract) => contract.id != contractId)
            .toList(growable: false);
      });
      _showMessage('돈 약속을 삭제했습니다.');
    } catch (_) {
      if (mounted) {
        _showMessage('돈 약속을 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // 삭제 또는 가리기 전에 사용자의 확인을 받는다.
  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // 화면 하단에 계약 처리 결과를 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColoredBox(
          color: AppColors.background,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenHorizontalPadding,
                AppDimensions.screenVerticalPadding,
                AppDimensions.screenHorizontalPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('돈 약속', style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppDimensions.sectionSpacing),
                  Expanded(child: _buildContractContent()),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: AppDimensions.screenHorizontalPadding,
          bottom: AppDimensions.screenVerticalPadding,
          child: FloatingActionButton(
            heroTag: 'create_contract_button',
            tooltip: '새 돈 약속 만들기',
            backgroundColor: AppColors.highlight,
            foregroundColor: AppColors.textPrimary,
            onPressed: isProcessing ? null : openCreateContractScreen,
            child: const Icon(Icons.add),
          ),
        ),
        if (isProcessing)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildContractContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage!,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            TextButton(onPressed: loadContracts, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (contracts.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadContracts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Text(
              '아직 등록된 돈 약속이 없습니다.\n새 돈 약속을 만들어 보세요.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadContracts,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 104),
        itemCount: contracts.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppDimensions.itemSpacing),
        itemBuilder: (context, index) {
          final contract = contracts[index];
          return ContractCard(
            contract: contract,
            currentUserUid: currentUserUid!,
            onTap: () => openContract(contract),
            onLongPress: () => showContractActions(contract),
          );
        },
      ),
    );
  }
}
