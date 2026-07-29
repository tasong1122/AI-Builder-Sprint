import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/app_colors.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';

// Firebase를 초기화한 뒤 로그인 상태에 맞는 첫 화면을 실행한다.
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
      title: 'lOV',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.highlight),
      ),
      home: const LoginScreen(),
    );
  }
}
