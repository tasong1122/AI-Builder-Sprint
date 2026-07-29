import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_text_field.dart';
import '../main/main_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  // 계정과 사용자 문서를 생성하고 성공하면 홈 탭으로 이동한다.
  Future<void> signUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmation = confirmationController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('모든 입력값을 작성해 주세요.');
      return;
    }
    if (password != confirmation) {
      _showMessage('비밀번호 확인 값이 일치하지 않습니다.');
      return;
    }

    setState(() => isSubmitting = true);
    try {
      await AuthService().signUp(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: confirmation,
      );
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
        _showMessage(
          error.code == 'email-already-in-use'
              ? '이미 가입된 이메일입니다.'
              : '회원가입하지 못했습니다. 입력값을 확인해 주세요.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('회원가입하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  // 화면 하단에 회원가입 안내 메시지를 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
          child: Column(
            children: [
              CommonTextField(controller: nameController, label: '사용자 이름'),
              const SizedBox(height: AppDimensions.itemSpacing),
              CommonTextField(
                controller: emailController,
                label: '이메일',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppDimensions.itemSpacing),
              CommonTextField(
                controller: passwordController,
                label: '비밀번호',
                obscureText: true,
              ),
              const SizedBox(height: AppDimensions.itemSpacing),
              CommonTextField(
                controller: confirmationController,
                label: '비밀번호 확인',
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!isSubmitting) {
                    signUp();
                  }
                },
              ),
              const SizedBox(height: AppDimensions.sectionSpacing),
              CommonButton(
                label: '회원가입',
                isLoading: isSubmitting,
                onPressed: isSubmitting ? null : signUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
