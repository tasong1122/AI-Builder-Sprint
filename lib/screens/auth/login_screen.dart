import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_text_field.dart';
import '../main/main_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isSubmitting = false;
  bool obscurePassword = true;
  String? emailErrorText;
  String? passwordErrorText;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // 이메일과 비밀번호를 검증하고 로그인 후 홈 탭으로 이동한다.
  Future<void> signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    setState(() {
      emailErrorText = email.isEmpty ? '이메일을 입력해 주세요.' : null;
      passwordErrorText = password.isEmpty ? '비밀번호를 입력해 주세요.' : null;
    });
    if (email.isEmpty || password.isEmpty) {
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await AuthService().signIn(email: email, password: password);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainScreen(initialTabIndex: 0),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showMessage(_authErrorMessage(error.code));
      }
    } catch (_) {
      if (mounted) {
        _showMessage('로그인하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  // 인증 오류 코드를 사용자용 메시지로 변환한다.
  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return '올바른 이메일 형식을 입력해 주세요.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      default:
        return '로그인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }

  // 화면 하단에 오류 메시지를 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(
              AppDimensions.screenHorizontalPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('lOV', style: AppTextStyles.screenTitle),
                  const SizedBox(height: 40),
                  CommonTextField(
                    controller: emailController,
                    label: '이메일',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    errorText: emailErrorText,
                    enabled: !isSubmitting,
                    onChanged: (_) => setState(() => emailErrorText = null),
                  ),
                  const SizedBox(height: AppDimensions.itemSpacing),
                  CommonTextField(
                    controller: passwordController,
                    label: '비밀번호',
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.done,
                    errorText: passwordErrorText,
                    enabled: !isSubmitting,
                    onChanged: (_) => setState(() => passwordErrorText = null),
                    onSubmitted: (_) {
                      if (!isSubmitting) {
                        signIn();
                      }
                    },
                    suffixIcon: IconButton(
                      onPressed: isSubmitting
                          ? null
                          : () => setState(
                              () => obscurePassword = !obscurePassword,
                            ),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),
                  CommonButton(
                    label: '로그인',
                    isLoading: isSubmitting,
                    onPressed: isSubmitting ? null : signIn,
                  ),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SignUpScreen(),
                            ),
                          ),
                    child: const Text('계정이 없으신가요? 회원가입'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
