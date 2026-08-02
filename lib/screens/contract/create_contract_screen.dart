import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/kakao_config.dart';
import '../../models/contract_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/contract_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_text_field.dart';

class CreateContractScreen extends StatefulWidget {
  const CreateContractScreen({super.key, this.contractId});

  final String? contractId;

  @override
  State<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final amountController = TextEditingController();
  final dueDateController = TextEditingController();
  final interestRateController = TextEditingController();
  final memoController = TextEditingController();

  UserModel? currentUser;
  ContractModel? editingContract;
  bool isLoading = true;
  bool isSubmitting = false;
  bool hasInterest = false;
  String? loadErrorMessage;
  String? amountErrorText;
  String? dueDateErrorText;
  String? interestRateErrorText;
  DateTime? selectedDueDate;

  bool get isEditingExisting => widget.contractId != null;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    amountController.dispose();
    dueDateController.dispose();
    interestRateController.dispose();
    memoController.dispose();
    super.dispose();
  }

  // 현재 사용자와 수정할 editing 계약 정보를 불러온다.
  Future<void> loadInitialData() async {
    setState(() {
      isLoading = true;
      loadErrorMessage = null;
    });

    try {
      final user = await AuthService().getCurrentUserProfile();
      ContractModel? contract;
      if (widget.contractId != null) {
        contract = await ContractService().getContract(widget.contractId!);
        if (contract.status != ContractStatus.editing ||
            contract.creatorUid != user.uid) {
          throw StateError('수정할 수 없는 돈 약속입니다.');
        }
      }

      if (!mounted) {
        return;
      }
      currentUser = user;
      editingContract = contract;
      if (contract != null) {
        _fillControllers(contract);
      }
      setState(() {
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
        loadErrorMessage = '돈 약속 정보를 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.';
      });
    }
  }

  // 기존 계약 값을 입력 컨트롤러와 선택 상태에 반영한다.
  void _fillControllers(ContractModel contract) {
    amountController.text = contract.principalAmount.toString();
    selectedDueDate = contract.dueDate;
    dueDateController.text = _formatDate(contract.dueDate);
    hasInterest = contract.interestRate > 0;
    interestRateController.text = hasInterest
        ? _formatRate(contract.interestRate)
        : '';
    memoController.text = contract.memo;
  }

  // 상환 날짜 선택기를 열고 선택한 날짜를 입력값에 반영한다.
  Future<void> selectDueDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDueDate ?? firstDate.add(const Duration(days: 30)),
      firstDate: firstDate,
      lastDate: DateTime(now.year + 30, 12, 31),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      selectedDueDate = pickedDate;
      dueDateController.text = _formatDate(pickedDate);
      dueDateErrorText = null;
    });
  }

  // 입력값을 editing 계약 모델로 변환하고 잘못된 값은 화면에 표시한다.
  ContractModel? buildContract() {
    final user = currentUser;
    final principalAmount = int.tryParse(amountController.text.trim());
    final interestRate = hasInterest
        ? double.tryParse(interestRateController.text.trim())
        : 0.0;

    setState(() {
      amountErrorText = principalAmount == null || principalAmount <= 0
          ? '0원보다 큰 금액을 입력해 주세요.'
          : null;
      dueDateErrorText = selectedDueDate == null ? '갚을 날짜를 선택해 주세요.' : null;
      interestRateErrorText =
          hasInterest && (interestRate == null || interestRate < 0)
          ? '올바른 이자율을 입력해 주세요.'
          : null;
    });

    if (user == null ||
        principalAmount == null ||
        principalAmount <= 0 ||
        selectedDueDate == null ||
        interestRate == null ||
        interestRate < 0) {
      return null;
    }

    final interestAmount = hasInterest
        ? (principalAmount * interestRate / 100).round()
        : 0;
    return ContractModel(
      id: editingContract?.id ?? '',
      lenderUid: editingContract?.lenderUid,
      lenderName: editingContract?.lenderName ?? '공유 링크로 등록 예정',
      borrowerUid: user.uid,
      borrowerName: user.name,
      creatorUid: user.uid,
      principalAmount: principalAmount,
      interestRate: hasInterest ? interestRate : 0,
      interestAmount: interestAmount,
      totalRepaymentAmount: principalAmount + interestAmount,
      dueDate: selectedDueDate!,
      lenderAgreed: false,
      borrowerAgreed: false,
      status: ContractStatus.editing,
      memo: memoController.text.trim(),
    );
  }

  // 새 계약을 생성하거나 기존 editing 계약을 수정해 임시 저장한다.
  Future<String?> saveEditingContract({
    bool showCompletionMessage = true,
  }) async {
    if (isSubmitting) {
      return null;
    }
    final contract = buildContract();
    if (contract == null) {
      return null;
    }

    setState(() {
      isSubmitting = true;
    });
    try {
      final contractService = ContractService();
      String contractId;
      if (editingContract == null) {
        contractId = await contractService.createContract(contract);
        editingContract = contract.copyWith(id: contractId);
      } else {
        contractId = editingContract!.id;
        final updatedContract = contract.copyWith(id: contractId);
        await contractService.updateEditingContract(updatedContract);
        editingContract = updatedContract;
      }

      if (!mounted) {
        return contractId;
      }
      if (showCompletionMessage) {
        _showMessage('돈 약속을 임시 저장했습니다.');
      }
      setState(() {
        isSubmitting = false;
      });
      return contractId;
    } catch (_) {
      if (!mounted) {
        return null;
      }
      setState(() {
        isSubmitting = false;
      });
      _showMessage('돈 약속을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      return null;
    }
  }

  // 계약을 저장하고 동의 대기 상태로 변경한 뒤 공유 링크를 제공한다.
  Future<void> sendContract() async {
    final contractId = await saveEditingContract(showCompletionMessage: false);
    if (contractId == null || !mounted) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });
    try {
      await ContractService().sendContract(contractId);
      if (!mounted) {
        return;
      }
      final contractLink = 'https://yaksok.app/contracts/$contractId';
      await _showShareLinkDialog(contractLink);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('돈 약속을 보내지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // 돈 약속 링크를 시스템 공유창으로 보내거나 복사할 수 있게 표시한다.
  Future<void> _showShareLinkDialog(String contractLink) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('돈 약속 링크가 만들어졌습니다'),
          content: SelectableText(contractLink),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: contractLink));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('링크 복사'),
            ),
            TextButton(
              onPressed: () =>
                  _shareContractLinkToKakao(dialogContext, contractLink),
              child: const Text('카카오톡'),
            ),
            Builder(
              builder: (shareButtonContext) {
                return TextButton(
                  onPressed: () => _shareContractLink(
                    shareButtonContext,
                    dialogContext,
                    contractLink,
                  ),
                  child: const Text('다른 앱'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // 카카오톡 피드 템플릿으로 이미지가 포함된 카드형 메시지를 공유한다.
  Future<void> _shareContractLinkToKakao(
    BuildContext dialogContext,
    String contractLink,
  ) async {
    try {
      final contractId = Uri.parse(contractLink).pathSegments.last;
      final link = Link(
        webUrl: Uri.parse(contractLink),
        mobileWebUrl: Uri.parse(contractLink),
        androidExecutionParams: {'contract_id': contractId},
        iosExecutionParams: {'contract_id': contractId},
      );
      final template = FeedTemplate(
        content: Content(
          title: '새로운 돈 약속이 도착했어요',
          description: '친구가 보낸 돈 약속을 lOV에서 확인해 보세요.',
          imageUrl: Uri.parse(KakaoConfig.shareImageUrl),
          imageWidth: 1774,
          imageHeight: 887,
          link: link,
        ),
        buttons: [Button(title: '돈 약속 확인하기', link: link)],
      );

      final canShareWithKakao = await ShareClient.instance
          .isKakaoTalkSharingAvailable();
      if (canShareWithKakao) {
        await ShareClient.instance.shareDefault(template: template);
      } else {
        final shareUrl = await WebSharerClient.instance.makeDefaultUrl(
          template: template,
        );
        await launchBrowser(shareUrl);
      }

      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('카카오톡 공유를 열지 못했습니다. 다른 앱 공유를 이용해 주세요.');
      }
    }
  }

  // Android와 iOS의 시스템 공유창을 열어 돈 약속 링크를 전달한다.
  Future<void> _shareContractLink(
    BuildContext shareButtonContext,
    BuildContext dialogContext,
    String contractLink,
  ) async {
    try {
      final renderBox = shareButtonContext.findRenderObject() as RenderBox?;
      final shareOrigin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'lOV 돈 약속',
          subject: 'lOV에서 돈 약속이 도착했어요',
          text:
              'lOV에서 보낸 돈 약속이에요.\n'
              '$contractLink\n'
              '링크를 열거나 lOV 홈에서 붙여넣어 확인해 주세요.',
          sharePositionOrigin: shareOrigin,
        ),
      );

      if (!dialogContext.mounted) {
        return;
      }
      if (result.status == ShareResultStatus.unavailable) {
        _showMessage('이 기기에서는 공유창을 열 수 없습니다. 링크 복사를 이용해 주세요.');
        return;
      }
      Navigator.of(dialogContext).pop();
    } catch (_) {
      if (mounted) {
        _showMessage('공유창을 열지 못했습니다. 링크 복사를 이용해 주세요.');
      }
    }
  }

  // 화면 하단에 계약 처리 결과를 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) =>
      '${date.year}년 ${date.month}월 ${date.day}일';

  String _formatRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toInt().toString() : rate.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(isEditingExisting ? '돈 약속 수정' : '새 돈 약속 만들기'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (loadErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loadErrorMessage!,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.itemSpacing),
              TextButton(
                onPressed: loadInitialData,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ParticipantField(label: '빌리는 사람', value: currentUser!.name),
            const SizedBox(height: AppDimensions.itemSpacing),
            CommonTextField(
              controller: amountController,
              label: '빌릴 금액',
              hintText: '금액을 입력해 주세요.',
              errorText: amountErrorText,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              enabled: !isSubmitting,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => amountErrorText = null),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            CommonTextField(
              controller: dueDateController,
              label: '갚을 날짜',
              hintText: '날짜를 선택해 주세요.',
              errorText: dueDateErrorText,
              readOnly: true,
              enabled: !isSubmitting,
              onTap: isSubmitting ? null : selectDueDate,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('이자 있음', style: AppTextStyles.body),
              value: hasInterest,
              activeTrackColor: AppColors.highlight,
              onChanged: isSubmitting
                  ? null
                  : (value) {
                      setState(() {
                        hasInterest = value;
                        interestRateErrorText = null;
                        if (!value) {
                          interestRateController.clear();
                        }
                      });
                    },
            ),
            if (hasInterest) ...[
              const SizedBox(height: AppDimensions.itemSpacing),
              CommonTextField(
                controller: interestRateController,
                label: '이자율 (%)',
                hintText: '예: 5',
                errorText: interestRateErrorText,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                enabled: !isSubmitting,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return RegExp(
                          r'^\d{0,3}(\.\d{0,2})?$',
                        ).hasMatch(newValue.text)
                        ? newValue
                        : oldValue;
                  }),
                ],
                onChanged: (_) => setState(() => interestRateErrorText = null),
              ),
            ],
            const SizedBox(height: AppDimensions.itemSpacing),
            CommonTextField(
              controller: memoController,
              label: '메모',
              hintText: '추가로 나눌 내용을 입력해 주세요.',
              maxLines: 4,
              enabled: !isSubmitting,
            ),
            const SizedBox(height: AppDimensions.sectionSpacing),
            OutlinedButton(
              onPressed: isSubmitting ? null : saveEditingContract,
              child: const Text('임시 저장'),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
            CommonButton(
              label: '돈 약속 보내기',
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : sendContract,
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantField extends StatelessWidget {
  const _ParticipantField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.neutralSection,
        borderRadius: BorderRadius.circular(AppDimensions.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
