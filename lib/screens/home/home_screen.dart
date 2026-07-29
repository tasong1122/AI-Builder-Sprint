import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../models/contract_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/contract_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_text_field.dart';
import '../../widgets/contract_card.dart';
import '../auth/login_screen.dart';
import '../contract/detail_contract_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onContractJoined});

  final VoidCallback? onContractJoined;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final contractLinkController = TextEditingController();

  UserModel? currentUserProfile;
  List<ContractModel> activeContracts = const [];
  bool isDashboardLoading = true;
  bool isSigningOut = false;
  bool isJoiningContract = false;
  bool showAllContracts = false;
  String? dashboardErrorMessage;
  String? contractLinkErrorText;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  @override
  void dispose() {
    contractLinkController.dispose();
    super.dispose();
  }

  // 사용자 총액과 숨기지 않은 active 계약 목록을 함께 불러온다.
  Future<void> loadDashboard() async {
    if (mounted) {
      setState(() {
        isDashboardLoading = true;
        dashboardErrorMessage = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        AuthService().getCurrentUserProfile(),
        ContractService().getCurrentUserContracts(activeOnly: true),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        currentUserProfile = results[0] as UserModel;
        activeContracts = results[1] as List<ContractModel>;
        isDashboardLoading = false;
        if (activeContracts.length <= 3) {
          showAllContracts = false;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        isDashboardLoading = false;
        dashboardErrorMessage = '홈 정보를 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.';
      });
    }
  }

  // Firebase 인증 세션을 종료하고 로그인 화면으로 이동한다.
  Future<void> signOut() async {
    if (isSigningOut) {
      return;
    }
    setState(() {
      isSigningOut = true;
    });

    try {
      await AuthService().signOut();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('로그아웃하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      setState(() {
        isSigningOut = false;
      });
    }
  }

  // 입력한 공유 링크에서 계약 ID를 추출해 현재 사용자를 계약에 연결한다.
  Future<void> joinContractFromLink() async {
    if (isJoiningContract || isSigningOut) {
      return;
    }
    final contractId = _extractContractId(contractLinkController.text);
    if (contractId == null) {
      setState(() {
        contractLinkErrorText = '올바른 돈 약속 링크를 입력해 주세요.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      isJoiningContract = true;
      contractLinkErrorText = null;
    });
    try {
      await ContractService().joinContract(contractId);
      if (!mounted) {
        return;
      }
      contractLinkController.clear();
      _showMessage('돈 약속을 등록했습니다.');
      widget.onContractJoined?.call();
    } on StateError catch (error) {
      if (mounted) {
        _showMessage(error.message.toString());
      }
    } catch (_) {
      if (mounted) {
        _showMessage('돈 약속을 등록하지 못했습니다. 링크를 확인해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isJoiningContract = false;
        });
      }
    }
  }

  // 진행 중 계약의 읽기 전용 상세 화면을 열고 돌아오면 홈을 갱신한다.
  Future<void> openContractDetail(ContractModel contract) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DetailContractScreen(contractId: contract.id),
      ),
    );
    if (changed == true && mounted) {
      await loadDashboard();
    }
  }

  // 지원하는 계약 URL 또는 Firestore 계약 ID에서 안전한 ID만 반환한다.
  String? _extractContractId(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }
    final idPattern = RegExp(r'^[A-Za-z0-9_-]{8,128}$');
    if (idPattern.hasMatch(value)) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      return null;
    }
    final queryId = uri.queryParameters['contract_id'];
    if (queryId != null && idPattern.hasMatch(queryId)) {
      return queryId;
    }
    if (uri.pathSegments.length >= 2 &&
        uri.pathSegments[uri.pathSegments.length - 2] == 'contracts') {
      final pathId = uri.pathSegments.last;
      return idPattern.hasMatch(pathId) ? pathId : null;
    }
    return null;
  }

  // 화면 하단에 처리 결과를 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadDashboard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            children: [
              _buildHeader(),
              const SizedBox(height: AppDimensions.sectionSpacing),
              _buildDashboard(),
              const SizedBox(height: AppDimensions.sectionSpacing),
              _buildContractLinkSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(child: Text('홈', style: AppTextStyles.screenTitle)),
        IconButton(
          tooltip: '로그아웃',
          onPressed: isSigningOut || isJoiningContract ? null : signOut,
          icon: isSigningOut
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    if (isDashboardLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (dashboardErrorMessage != null || currentUserProfile == null) {
      return _DashboardError(
        message: dashboardErrorMessage ?? '사용자 정보를 확인할 수 없습니다.',
        onRetry: loadDashboard,
      );
    }

    final profile = currentUserProfile!;
    final visibleContracts = showAllContracts
        ? activeContracts
        : activeContracts.take(3).toList(growable: false);
    final remainingCount = activeContracts.length - 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                label: '빌린 돈 합계',
                amount: profile.borrowedTotal,
                backgroundColor: AppColors.sectionBackground,
              ),
            ),
            const SizedBox(width: AppDimensions.itemSpacing),
            Expanded(
              child: _TotalCard(
                label: '빌려준 돈 합계',
                amount: profile.lentTotal,
                backgroundColor: AppColors.neutralSection,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sectionSpacing),
        const Text('최근 돈 약속', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppDimensions.itemSpacing),
        if (visibleContracts.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppDimensions.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.neutralSection,
              borderRadius: BorderRadius.circular(
                AppDimensions.defaultBorderRadius,
              ),
            ),
            child: const Text(
              '진행 중인 돈 약속이 없습니다.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final contract in visibleContracts) ...[
            ContractCard(
              contract: contract,
              currentUserUid: profile.uid,
              onTap: () => openContractDetail(contract),
            ),
            const SizedBox(height: AppDimensions.itemSpacing),
          ],
        if (remainingCount > 0)
          TextButton(
            onPressed: () {
              setState(() {
                showAllContracts = !showAllContracts;
              });
            },
            child: Text(showAllContracts ? '접기' : '$remainingCount건 더보기'),
          ),
      ],
    );
  }

  Widget _buildContractLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('돈 약속 링크 등록', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 6),
        const Text(
          '공유받은 돈 약속 링크를 붙여넣어 약속에 참여할 수 있습니다.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppDimensions.itemSpacing),
        CommonTextField(
          controller: contractLinkController,
          label: '돈 약속 링크',
          hintText: 'https://yaksok.app/contracts/...',
          errorText: contractLinkErrorText,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          enabled: !isJoiningContract && !isSigningOut,
          onChanged: (_) {
            if (contractLinkErrorText != null) {
              setState(() {
                contractLinkErrorText = null;
              });
            }
          },
          onSubmitted: (_) {
            if (!isJoiningContract) {
              joinContractFromLink();
            }
          },
          suffixIcon: IconButton(
            tooltip: '붙여넣기',
            onPressed: isJoiningContract ? null : pasteContractLink,
            icon: const Icon(Icons.content_paste_outlined),
          ),
        ),
        const SizedBox(height: AppDimensions.itemSpacing),
        CommonButton(
          label: '돈 약속 링크 열기',
          isLoading: isJoiningContract,
          onPressed: isJoiningContract || isSigningOut
              ? null
              : joinContractFromLink,
        ),
      ],
    );
  }

  // 클립보드의 텍스트를 계약 링크 입력창에 붙여넣는다.
  Future<void> pasteContractLink() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || clipboardData?.text == null) {
      return;
    }
    setState(() {
      contractLinkController.text = clipboardData!.text!;
      contractLinkErrorText = null;
    });
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.backgroundColor,
  });

  final String label;
  final int amount;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.defaultBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatWon(amount),
              style: AppTextStyles.sectionTitle,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.neutralSection,
        borderRadius: BorderRadius.circular(AppDimensions.defaultBorderRadius),
      ),
      child: Column(
        children: [
          Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.itemSpacing),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
