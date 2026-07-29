import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/app_dimensions.dart';
import '../../constants/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_button.dart';
import '../../widgets/common_text_field.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final newEmailController = TextEditingController();
  bool isSendingEmailChange = false;
  bool isSendingPasswordReset = false;
  bool isSigningOut = false;
  String? emailErrorText;
  String currentEmail = '확인할 수 없음';

  @override
  void initState() {
    super.initState();
    loadCurrentEmail();
  }

  @override
  void dispose() {
    newEmailController.dispose();
    super.dispose();
  }

  // 초기화된 Firebase 계정에서 현재 로그인 이메일을 안전하게 불러온다.
  void loadCurrentEmail() {
    try {
      currentEmail = FirebaseAuth.instance.currentUser?.email ?? '확인할 수 없음';
    } on FirebaseException {
      currentEmail = '확인할 수 없음';
    }
  }

  // 새 이메일 주소의 소유 여부를 확인할 변경 링크를 발송한다.
  Future<void> sendEmailChangeVerification() async {
    if (isSendingEmailChange) {
      return;
    }
    setState(() {
      isSendingEmailChange = true;
      emailErrorText = null;
    });
    try {
      await AuthService().sendEmailChangeVerification(newEmailController.text);
      if (!mounted) {
        return;
      }
      newEmailController.clear();
      _showMessage('새 이메일로 확인 링크를 보냈습니다.');
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => emailErrorText = error.message);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showMessage(_authErrorMessage(error.code));
      }
    } catch (_) {
      if (mounted) {
        _showMessage('이메일 변경 메일을 보내지 못했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => isSendingEmailChange = false);
      }
    }
  }

  // 현재 계정 이메일로 비밀번호 재설정 링크를 발송한다.
  Future<void> sendPasswordResetEmail() async {
    if (isSendingPasswordReset) {
      return;
    }
    setState(() => isSendingPasswordReset = true);
    try {
      await AuthService().sendPasswordResetEmail();
      if (mounted) {
        _showMessage('현재 이메일로 비밀번호 재설정 링크를 보냈습니다.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showMessage(_authErrorMessage(error.code));
      }
    } catch (_) {
      if (mounted) {
        _showMessage('비밀번호 재설정 메일을 보내지 못했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() => isSendingPasswordReset = false);
      }
    }
  }

  // Firebase 인증 세션을 종료하고 로그인 화면으로 이동한다.
  Future<void> signOut() async {
    if (isSigningOut) {
      return;
    }
    setState(() => isSigningOut = true);
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
      if (mounted) {
        _showMessage('로그아웃하지 못했습니다.');
        setState(() => isSigningOut = false);
      }
    }
  }

  // Firebase 오류 코드를 사용자용 안내 문구로 변환한다.
  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return '올바른 이메일 주소를 입력해 주세요.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'requires-recent-login':
        return '보안을 위해 로그아웃 후 다시 로그인해 주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      default:
        return '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }

  // 화면 하단에 처리 결과를 표시한다.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppDimensions.screenHorizontalPadding),
        children: [
          const Text('설정', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppDimensions.sectionSpacing),
          const Text('계정', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppDimensions.itemSpacing),
          Text('현재 이메일(ID): $currentEmail', style: AppTextStyles.body),
          const SizedBox(height: AppDimensions.itemSpacing),
          CommonTextField(
            controller: newEmailController,
            label: '새 이메일(ID)',
            keyboardType: TextInputType.emailAddress,
            errorText: emailErrorText,
            enabled: !isSendingEmailChange,
            onChanged: (_) => setState(() => emailErrorText = null),
          ),
          const SizedBox(height: AppDimensions.itemSpacing),
          CommonButton(
            label: '이메일 변경 링크 보내기',
            isLoading: isSendingEmailChange,
            onPressed: isSendingEmailChange
                ? null
                : sendEmailChangeVerification,
          ),
          const SizedBox(height: AppDimensions.itemSpacing),
          OutlinedButton.icon(
            onPressed: isSendingPasswordReset ? null : sendPasswordResetEmail,
            icon: isSendingPasswordReset
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_reset),
            label: const Text('비밀번호 재설정 메일 보내기'),
          ),
          const SizedBox(height: AppDimensions.sectionSpacing),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('다크 모드'),
            subtitle: const Text('어두운 화면 테마를 사용합니다.'),
            value: widget.isDarkMode,
            onChanged: widget.onDarkModeChanged,
          ),
          const Divider(),
          const SizedBox(height: AppDimensions.itemSpacing),
          OutlinedButton.icon(
            onPressed: isSigningOut ? null : signOut,
            icon: const Icon(Icons.logout),
            label: Text(isSigningOut ? '로그아웃 중...' : '로그아웃'),
          ),
        ],
      ),
    );
  }
}
