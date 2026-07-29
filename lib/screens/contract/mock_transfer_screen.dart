import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../models/contract_model.dart';
import '../../services/auth_service.dart';
import '../../services/contract_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/contract_card.dart';
import '../main/main_screen.dart';

enum MockTransferType { lend, repay }

class MockTransferScreen extends StatefulWidget {
  const MockTransferScreen({
    super.key,
    required this.contract,
    required this.transferType,
  });

  final ContractModel contract;
  final MockTransferType transferType;

  @override
  State<MockTransferScreen> createState() => _MockTransferScreenState();
}

class _MockTransferScreenState extends State<MockTransferScreen> {
  bool isSubmitting = false;
  String? accessErrorMessage;

  bool get isLending => widget.transferType == MockTransferType.lend;

  String get recipientName =>
      isLending ? widget.contract.borrowerName : widget.contract.lenderName;

  @override
  void initState() {
    super.initState();
    validateAccess();
  }

  // 현재 UID와 계약 상태가 전달받은 송금 경로에 맞는지 확인한다.
  void validateAccess() {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) {
        throw StateError('로그인이 필요합니다.');
      }

      final canLend =
          isLending &&
          widget.contract.status == ContractStatus.waitingAgreement &&
          widget.contract.isLender(uid);
      final canRepay =
          !isLending &&
          widget.contract.status == ContractStatus.active &&
          widget.contract.isBorrower(uid);
      if (!canLend && !canRepay) {
        throw StateError('이 송금을 진행할 권한이 없습니다.');
      }
    } catch (_) {
      accessErrorMessage = '송금 정보를 확인할 수 없습니다.\n돈 약속 상태를 다시 확인해 주세요.';
    }
  }

  // 송금 확인 전에 사용자의 최종 동의를 받는다.
  Future<void> requestTransferConfirmation() async {
    if (isSubmitting || accessErrorMessage != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isLending ? '빌려주기 확인' : '갚기 확인'),
          content: Text(
            '$recipientName 님에게 '
            '${formatWon(widget.contract.totalRepaymentAmount)}을 '
            '${isLending ? '빌려주시겠습니까?' : '갚으시겠습니까?'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await completeTransfer();
    }
  }

  // 경로에 맞는 transaction을 실행하고 완료 후 홈 탭으로 이동한다.
  Future<void> completeTransfer() async {
    setState(() {
      isSubmitting = true;
    });

    try {
      final contractService = ContractService();
      if (isLending) {
        await contractService.agreeToContract(widget.contract.id);
      } else {
        await contractService.completeRepayment(widget.contract.id);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainScreen(initialTabIndex: 0),
        ),
        (_) => false,
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('송금을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // 화면 하단에 송금 처리 오류를 안전하게 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSubmitting,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(isLending ? '빌려주기' : '갚기'),
          automaticallyImplyLeading: !isSubmitting,
        ),
        body: accessErrorMessage != null
            ? _TransferErrorView(message: accessErrorMessage!)
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(
                    AppDimensions.screenHorizontalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Icon(
                        isLending
                            ? Icons.volunteer_activism_outlined
                            : Icons.payments_outlined,
                        size: 64,
                        color: AppColors.highlight,
                      ),
                      const SizedBox(height: AppDimensions.sectionSpacing),
                      Text(
                        '$recipientName 님에게',
                        style: AppTextStyles.sectionTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.itemSpacing),
                      Text(
                        '${formatWon(widget.contract.totalRepaymentAmount)}을\n'
                        '${isLending ? '빌려주시겠습니까?' : '갚으시겠습니까?'}',
                        style: AppTextStyles.screenTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.itemSpacing),
                      const Text(
                        '실제 금융 송금은 발생하지 않는 MVP용 가상 송금입니다.',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      CommonButton(
                        label: isLending ? '빌려주기 확인' : '갚기 확인',
                        isLoading: isSubmitting,
                        onPressed: isSubmitting
                            ? null
                            : requestTransferConfirmation,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _TransferErrorView extends StatelessWidget {
  const _TransferErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
        child: Text(
          message,
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
