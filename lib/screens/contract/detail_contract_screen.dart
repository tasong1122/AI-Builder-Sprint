import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../models/contract_model.dart';
import '../../services/auth_service.dart';
import '../../services/contract_service.dart';
import '../../services/notification_service.dart';
import '../../services/upstage_ai_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/contract_card.dart';
import '../../widgets/common_text_field.dart';
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
  final notificationService = NotificationService();

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

  // 독촉문자 입력 시트를 열고 전송 결과를 안내한다.
  Future<void> openReminderMessageSheet(ContractModel contract) async {
    final currentUid = currentUserUid;
    final recipientUid = contract.borrowerUid;

    if (currentUid == null ||
        recipientUid == null ||
        !contract.isLender(currentUid)) {
      _showMessage('독촉문자를 보낼 수 없는 돈 약속입니다.');
      return;
    }

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.defaultBorderRadius),
        ),
      ),
      builder: (_) => _ReminderMessageSheet(
        contract: contract,
        senderUid: currentUid,
        senderName: contract.lenderName,
        recipientUid: recipientUid,
        recipientName: contract.borrowerName,
        notificationService: notificationService,
      ),
    );

    if (!mounted || sent != true) {
      return;
    }
    _showMessage('독촉문자를 보냈습니다.');
  }

  // 화면 하단에 처리 결과를 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
    final canSendReminder =
        uid != null &&
        contract.status == ContractStatus.active &&
        contract.isLender(uid);

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

    final actionLabel = label;
    final actionTransferType = transferType;

    if (actionLabel == null && !canSendReminder) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (actionLabel != null && actionTransferType != null)
              CommonButton(
                label: actionLabel,
                onPressed: () => openMockTransfer(contract, actionTransferType),
              ),
            if (canSendReminder) ...[
              if (actionLabel != null && actionTransferType != null)
                const SizedBox(height: AppDimensions.itemSpacing),
              OutlinedButton.icon(
                onPressed: () => openReminderMessageSheet(contract),
                icon: const Icon(Icons.sms_outlined),
                label: const Text('독촉문자 보내기'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    AppDimensions.buttonHeight,
                  ),
                  textStyle: AppTextStyles.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.defaultBorderRadius,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReminderMessageSheet extends StatefulWidget {
  const _ReminderMessageSheet({
    required this.contract,
    required this.senderUid,
    required this.senderName,
    required this.recipientUid,
    required this.recipientName,
    required this.notificationService,
  });

  final ContractModel contract;
  final String senderUid;
  final String senderName;
  final String recipientUid;
  final String recipientName;
  final NotificationService notificationService;

  @override
  State<_ReminderMessageSheet> createState() => _ReminderMessageSheetState();
}

class _ReminderMessageSheetState extends State<_ReminderMessageSheet> {
  final messageController = TextEditingController();
  final upstageAiService = UpstageAiService();
  bool isSubmitting = false;
  bool isGeneratingAiMessage = false;
  String? messageErrorText;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  // Upstage API를 호출해 돈 약속 정보를 기반으로 독촉문구를 자동 작성한다.
  Future<void> fillAiMessage() async {
    if (isSubmitting || isGeneratingAiMessage) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      isGeneratingAiMessage = true;
      messageErrorText = null;
    });

    try {
      final generatedMessage = await upstageAiService.generateReminderMessage(
        contract: widget.contract,
        senderName: widget.senderName,
        recipientName: widget.recipientName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        messageController.text = generatedMessage;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final errorMessage =
          error is StateError &&
              error.message.toString().contains('UPSTAGE_API_KEY')
          ? 'UPSTAGE_API_KEY가 설정되지 않았습니다.'
          : 'AI 자동 작성에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingAiMessage = false;
        });
      }
    }
  }

  // 입력한 독촉문자를 상대방 알림으로 저장한다.
  Future<void> sendReminderMessage() async {
    if (isSubmitting) {
      return;
    }

    final message = messageController.text.trim();
    if (message.isEmpty) {
      setState(() {
        messageErrorText = '메세지를 입력해 주세요.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      isSubmitting = true;
      messageErrorText = null;
    });

    try {
      await widget.notificationService.sendReminderNotification(
        recipientUid: widget.recipientUid,
        senderUid: widget.senderUid,
        senderName: widget.senderName,
        contractId: widget.contract.id,
        message: message,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isSubmitting = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('메세지를 보내지 못했습니다. 잠시 후 다시 시도해 주세요.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.screenHorizontalPadding,
        AppDimensions.sectionSpacing,
        AppDimensions.screenHorizontalPadding,
        MediaQuery.of(context).viewInsets.bottom +
            AppDimensions.screenVerticalPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('독촉 메세지 보내기', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppDimensions.itemSpacing),
            _DetailField(label: '받는 사람', value: widget.recipientName),
            const SizedBox(height: AppDimensions.itemSpacing),
            CommonTextField(
              controller: messageController,
              label: '메세지 작성',
              hintText: '메세지를 입력해 주세요.',
              errorText: messageErrorText,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              enabled: !isSubmitting,
              onChanged: (_) {
                if (messageErrorText != null) {
                  setState(() {
                    messageErrorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            OutlinedButton.icon(
              onPressed: isSubmitting || isGeneratingAiMessage
                  ? null
                  : fillAiMessage,
              icon: isGeneratingAiMessage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(isGeneratingAiMessage ? 'AI 작성 중...' : 'AI 자동 작성'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                textStyle: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.defaultBorderRadius,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            CommonButton(
              label: '메세지 보내기',
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : sendReminderMessage,
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
