import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

import 'constants/app_theme.dart';
import 'constants/kakao_config.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_screen.dart';
import 'services/contract_link_service.dart';

// Firebase를 초기화한 뒤 로그인 상태에 맞는 첫 화면을 실행한다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await KakaoSdk.init(nativeAppKey: KakaoConfig.nativeAppKey);
  await ContractLinkService.initialize();
  runApp(const YaksokApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ContractLinkService.openPendingContractIfPossible();
  });
}

class YaksokApp extends StatelessWidget {
  const YaksokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, themeMode, _) => MaterialApp(
        navigatorKey: ContractLinkService.navigatorKey,
        scaffoldMessengerKey: ContractLinkService.scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'lOV',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  // Firebase 인증 세션 복원 결과에 따라 로그인 또는 메인 화면을 표시한다.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainScreen(initialTabIndex: 0);
        }

        return const LoginScreen();
      },
    );
  }
}
