import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/app_colors.dart';
import 'constants/app_dimensions.dart';
import 'constants/app_text_styles.dart';
import 'firebase_options.dart';
import 'models/contract_model.dart';
import 'widgets/common_button.dart';
import 'widgets/common_text_field.dart';
import 'widgets/contract_card.dart';
import 'widgets/contract_status_badge.dart';

// Firebase를 초기화한 뒤 공통 위젯 디버그 앱을 실행한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const YaksokApp());
}

class YaksokApp extends StatelessWidget {
  const YaksokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '약속 UI 디버그',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.highlight),
      ),
      home: const WidgetDebugScreen(),
    );
  }
}

class WidgetDebugScreen extends StatefulWidget {
  const WidgetDebugScreen({super.key});

  @override
  State<WidgetDebugScreen> createState() => _WidgetDebugScreenState();
}

class _WidgetDebugScreenState extends State<WidgetDebugScreen> {
  final TextEditingController nameController = TextEditingController();

  bool isButtonLoading = false;
  String? inputErrorText;
  String inputReactionText = '입력창에 이름을 작성해 보세요.';

  late final List<ContractModel> sampleContracts;

  @override
  void initState() {
    super.initState();
    sampleContracts = [
      _createSampleContract(
        id: 'editing_sample',
        otherPartyName: '김지수',
        amount: 100000,
        status: ContractStatus.editing,
        dueDate: DateTime(2026, 8, 10),
      ),
      _createSampleContract(
        id: 'waiting_sample',
        otherPartyName: '이민준',
        amount: 500000,
        status: ContractStatus.waitingAgreement,
        dueDate: DateTime(2026, 9, 15),
      ),
      _createSampleContract(
        id: 'active_sample',
        otherPartyName: '박서연',
        amount: 1050000,
        status: ContractStatus.active,
        dueDate: DateTime(2026, 12, 31),
      ),
    ];
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // 입력값과 버튼의 로딩 반응을 순서대로 확인한다.
  Future<void> handleStartButton() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        inputErrorText = '이름을 입력해 주세요.';
      });
      return;
    }

    setState(() {
      inputErrorText = null;
      isButtonLoading = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) {
      return;
    }

    setState(() {
      isButtonLoading = false;
    });
    showDebugMessage('$name 님, 버튼 반응이 정상입니다.');
  }

  // 입력값 변경 결과를 화면에 즉시 표시한다.
  void handleNameChanged(String value) {
    setState(() {
      inputErrorText = null;
      inputReactionText = value.trim().isEmpty
          ? '입력창에 이름을 작성해 보세요.'
          : '현재 입력값: ${value.trim()}';
    });
  }

  // 카드 상호작용 결과를 하단 메시지로 표시한다.
  void showDebugMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Firestore 연결 없이 카드 디자인을 확인할 샘플 계약을 만든다.
  ContractModel _createSampleContract({
    required String id,
    required String otherPartyName,
    required int amount,
    required ContractStatus status,
    required DateTime dueDate,
  }) {
    return ContractModel(
      id: id,
      lenderUid: 'current_debug_user',
      lenderName: '나',
      borrowerUid: 'sample_$id',
      borrowerName: otherPartyName,
      creatorUid: 'current_debug_user',
      principalAmount: amount,
      interestRate: 0,
      interestAmount: 0,
      totalRepaymentAmount: amount,
      dueDate: dueDate,
      lenderAgreed: status == ContractStatus.active,
      borrowerAgreed: status == ContractStatus.active,
      status: status,
      memo: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('공통 위젯 디버그'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (_, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(
                AppDimensions.screenHorizontalPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('입력창', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: AppDimensions.itemSpacing),
                      CommonTextField(
                        controller: nameController,
                        label: '사용자 이름',
                        hintText: '이름을 입력해 주세요.',
                        errorText: inputErrorText,
                        textInputAction: TextInputAction.done,
                        onChanged: handleNameChanged,
                        onSubmitted: (_) => handleStartButton(),
                      ),
                      const SizedBox(height: 8),
                      Text(inputReactionText, style: AppTextStyles.caption),
                      const SizedBox(height: AppDimensions.sectionSpacing),
                      const Text('버튼', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: AppDimensions.itemSpacing),
                      CommonButton(
                        label: '시작하기',
                        isLoading: isButtonLoading,
                        onPressed: handleStartButton,
                      ),
                      const SizedBox(height: AppDimensions.itemSpacing),
                      const CommonButton(label: '비활성화 버튼', onPressed: null),
                      const SizedBox(height: AppDimensions.sectionSpacing),
                      const Text('상태 배지', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: AppDimensions.itemSpacing),
                      const Wrap(
                        spacing: AppDimensions.itemSpacing,
                        runSpacing: AppDimensions.itemSpacing,
                        children: [
                          ContractStatusBadge(status: ContractStatus.editing),
                          ContractStatusBadge(
                            status: ContractStatus.waitingAgreement,
                          ),
                          ContractStatusBadge(status: ContractStatus.active),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.sectionSpacing),
                      const Text('계약 카드', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 4),
                      const Text(
                        '카드를 누르거나 길게 눌러 반응을 확인하세요.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: AppDimensions.itemSpacing),
                      for (final contract in sampleContracts) ...[
                        ContractCard(
                          contract: contract,
                          currentUserUid: 'current_debug_user',
                          onTap: () => showDebugMessage(
                            '${contract.status.displayName} 카드를 눌렀습니다.',
                          ),
                          onLongPress: () => showDebugMessage(
                            '${contract.otherPartyName('current_debug_user')} '
                            '계약 카드를 길게 눌렀습니다.',
                          ),
                        ),
                        const SizedBox(height: AppDimensions.itemSpacing),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
