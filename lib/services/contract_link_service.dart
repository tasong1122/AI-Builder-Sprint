import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

import '../screens/contract/detail_contract_screen.dart';
import '../screens/main/main_screen.dart';
import 'auth_service.dart';
import 'contract_service.dart';

abstract final class ContractLinkService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static String? _pendingContractId;
  static bool _isProcessing = false;
  static const _nativeChannel = MethodChannel('lov/contract_link');

  // 카카오 URL Scheme을 구독하고 최초 실행 전에 전달된 링크도 복구한다.
  static Future<void> initialize() async {
    receiveKakaoScheme((uri) {
      _receiveLink(uri, processImmediately: true);
    });

    try {
      final initialLink = await _nativeChannel.invokeMethod<String>(
        'getInitialLink',
      );
      if (initialLink != null && initialLink.isNotEmpty) {
        _receiveLink(Uri.parse(initialLink), processImmediately: false);
      }
    } on MissingPluginException {
      // Android와 iOS 외 플랫폼에서는 최초 링크 브리지가 없어도 실행한다.
    } on PlatformException {
      _showMessage('돈 약속 링크를 확인하지 못했습니다.');
    } on FormatException {
      _showMessage('올바르지 않은 돈 약속 링크입니다.');
    }
  }

  // 전달된 URL에서 돈 약속 ID를 검증하고 처리 대기열에 저장한다.
  static void _receiveLink(Uri uri, {required bool processImmediately}) {
    final contractId = uri.queryParameters['contract_id'];
    if (contractId == null || !_isValidContractId(contractId)) {
      _showMessage('올바르지 않은 돈 약속 링크입니다.');
      return;
    }
    _pendingContractId = contractId;
    if (processImmediately) {
      openPendingContractIfPossible();
    }
  }

  // 로그인 상태라면 대기 중인 돈 약속에 참여하고 상세 화면을 연다.
  static Future<bool> openPendingContractIfPossible() async {
    final contractId = _pendingContractId;
    if (contractId == null ||
        _isProcessing ||
        AuthService().currentUser == null) {
      return false;
    }

    _isProcessing = true;
    try {
      await ContractService().joinContract(contractId);
      _pendingContractId = null;

      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        _pendingContractId = contractId;
        return false;
      }
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const MainScreen(initialTabIndex: 1),
        ),
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) => DetailContractScreen(contractId: contractId),
          ),
        );
      });
      return true;
    } on StateError catch (error) {
      _showMessage(error.message.toString());
      return false;
    } catch (_) {
      _showMessage('돈 약속을 열지 못했습니다. 잠시 후 다시 시도해 주세요.');
      return false;
    } finally {
      _isProcessing = false;
    }
  }

  // Firestore 자동 문서 ID로 사용할 수 있는 안전한 문자열인지 확인한다.
  static bool _isValidContractId(String contractId) {
    return RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(contractId);
  }

  // 링크 처리 결과를 현재 화면에 안전하게 안내한다.
  static void _showMessage(String message) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
