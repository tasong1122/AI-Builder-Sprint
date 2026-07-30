import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../models/contract_model.dart';
import '../../services/auth_service.dart';
import '../../services/contract_service.dart';
import '../../services/reminder_message_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/contract_card.dart';
import '../../widgets/contract_status_badge.dart';
import 'mock_transfer_screen.dart';

class DetailContractScreen extends StatefulWidget {
  const DetailContractScreen({super.key, required this.contractId});

  final String contractId;

  @override
  State<DetailContractScreen> createState() => _DetailContractScreenState();
}

class _DetailContractScreenState extends State<DetailContractScreen> {
  String? currentUserUid;
  Stream<ContractModel>? contractStream;
  String? initialErrorMessage;
  bool isSendingReminder = false;

  @override
  void initState() {
    super.initState();
    prepareContractStream();
  }

  // 로그인 UID를 확인하고 계약 문서의 실시간 구독을 준비한다.
  void prepareContractStream() {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) {
        throw StateError('로그인이 필요합니다.');
      }
      currentUserUid = uid;
      contractStream = ContractService().watchContract(widget.contractId);
      initialErrorMessage = null;
    } catch (_) {
      initialErrorMessage = '돈 약속 정보를 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.';
    }
  }

  // 현재 계약과 송금 유형을 가상 송금 화면에 전달한다.
  Future<void> openMockTransfer(
    ContractModel contract,
    MockTransferType transferType,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            MockTransferScreen(contract: contract, transferType: transferType),
      ),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  // Upstage API로 독촉 문자를 생성한 뒤 기본 문자 앱을 연다.
  Future<void> sendReminderMessage(ContractModel contract) async {
    final uid = currentUserUid;
    if (uid == null || isSendingReminder) {
      return;
    }
    setState(() {
      isSendingReminder = true;
    });
    try {
      final service = ReminderMessageService();
      final message = await service.generateReminderMessage(
        contract: contract,
        currentUserUid: uid,
      );
      if (mounted) {
        await showReminderMessageDialog(message, service);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('독촉 문자를 준비하지 못했습니다. 잠시 후 다시 시도해 주세요.'),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSendingReminder = false;
        });
      }
    }
  }

  // Shows the generated reminder when the current platform cannot open SMS.
  Future<void> showReminderMessageDialog(
    String message,
    ReminderMessageService service,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('독촉문자 문안'),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              if (mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('독촉문자 문안을 복사했습니다.')),
                  );
              }
            },
            child: const Text('복사'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await service.openSmsComposer(body: message);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('문자 앱을 열 수 없어 문안만 표시했습니다.'),
                      ),
                    );
                }
              }
            },
            child: const Text('문자 앱 열기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('돈 약속 자세히'),
      ),
      body: initialErrorMessage != null
          ? _ErrorView(
              message: initialErrorMessage!,
              onRetry: () {
                setState(prepareContractStream);
              },
            )
          : StreamBuilder<ContractModel>(
              stream: contractStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _ErrorView(
                    message: '돈 약속 정보를 불러오지 못했습니다.\n삭제되었거나 확인할 수 없는 돈 약속입니다.',
                    onRetry: () {
                      setState(prepareContractStream);
                    },
                  );
                }

                final contract = snapshot.data!;
                return _ContractDetailContent(contract: contract);
              },
            ),
      bottomNavigationBar: initialErrorMessage == null
          ? StreamBuilder<ContractModel>(
              stream: contractStream,
              builder: (context, snapshot) {
                final contract = snapshot.data;
                if (contract == null) {
                  return const SizedBox.shrink();
                }
                return _buildActionArea(contract);
              },
            )
          : null,
    );
  }

  Widget _buildActionArea(ContractModel contract) {
    final uid = currentUserUid;
    String? label;
    MockTransferType? transferType;

    if (uid != null &&
        contract.status == ContractStatus.waitingAgreement &&
        contract.isLender(uid)) {
      label = '빌려주기';
      transferType = MockTransferType.lend;
    } else if (uid != null &&
        contract.status == ContractStatus.active &&
        contract.isBorrower(uid)) {
      label = '갚기';
      transferType = MockTransferType.repay;
    }

    final canSendReminder =
        uid != null &&
        contract.status == ContractStatus.active &&
        contract.isLender(uid);

    if ((label == null || transferType == null) && !canSendReminder) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.screenHorizontalPadding,
          AppDimensions.itemSpacing,
          AppDimensions.screenHorizontalPadding,
          AppDimensions.screenVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSendReminder) ...[
              CommonButton(
                label: '독촉문자 보내기',
                isLoading: isSendingReminder,
                onPressed: () => sendReminderMessage(contract),
              ),
              if (label != null && transferType != null)
                const SizedBox(height: AppDimensions.itemSpacing),
            ],
            if (label != null && transferType != null)
              CommonButton(
                label: label,
                onPressed: () => openMockTransfer(contract, transferType!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContractDetailContent extends StatelessWidget {
  const _ContractDetailContent({required this.contract});

  final ContractModel contract;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ContractStatusBadge(status: contract.status),
            ),
            const SizedBox(height: AppDimensions.sectionSpacing),
            _DetailField(
              label: '빌려주는 사람',
              value:
                  contract.lenderUid == null &&
                      contract.status == ContractStatus.waitingAgreement
                  ? '대기중'
                  : contract.lenderName,
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(label: '빌리는 사람', value: contract.borrowerName),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(
              label: '빌린 금액',
              value: formatWon(contract.principalAmount),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(
              label: '갚을 날짜',
              value: formatKoreanDate(contract.dueDate),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(
              label: '이자율',
              value: '${_formatRate(contract.interestRate)}%',
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(
              label: '이자 금액',
              value: formatWon(contract.interestAmount),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(
              label: '총 갚을 금액',
              value: formatWon(contract.totalRepaymentAmount),
              highlighted: true,
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(
              label: '메모',
              value: contract.memo.isEmpty ? '등록된 메모가 없습니다.' : contract.memo,
            ),
          ],
        ),
      ),
    );
  }

  String _formatRate(double rate) {
    return rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toString();
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.sectionBackground
            : AppColors.neutralSection,
        borderRadius: BorderRadius.circular(AppDimensions.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
