import 'package:flutter/services.dart';

import '../models/contract_model.dart';
import '../widgets/contract_card.dart';
import 'upstage_api_client.dart';

class ReminderMessageService {
  ReminderMessageService({String? apiKey, UpstageApiClient? upstageApiClient})
    : _apiKey =
          apiKey ??
          const String.fromEnvironment('UPSTAGE_API_KEY', defaultValue: ''),
      _upstageApiClient = upstageApiClient ?? UpstageApiClient();

  static const MethodChannel _smsChannel = MethodChannel(
    'yaksok/reminder_sms',
  );

  final String _apiKey;
  final UpstageApiClient _upstageApiClient;

  // Generates a polite repayment reminder message from the contract details.
  Future<String> generateReminderMessage({
    required ContractModel contract,
    required String currentUserUid,
  }) async {
    if (!contract.isLender(currentUserUid)) {
      throw StateError('Only the lender can send a reminder message.');
    }
    if (_apiKey.trim().isEmpty) {
      return _buildFallbackMessage(contract);
    }

    try {
      final content = await _upstageApiClient.createReminderMessage(
        apiKey: _apiKey,
        prompt: _buildPrompt(contract),
      );
      return _cleanSmsBody(content);
    } catch (_) {
      return _buildFallbackMessage(contract);
    }
  }

  // Opens the device SMS composer with the generated message.
  Future<void> openSmsComposer({required String body, String? phoneNumber}) {
    return _smsChannel.invokeMethod<void>('openSmsComposer', {
      'body': body,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phoneNumber': phoneNumber.trim(),
    });
  }

  String _buildPrompt(ContractModel contract) {
    return '''
Borrower name: ${contract.borrowerName}
Lender name: ${contract.lenderName}
Principal amount: ${formatWon(contract.principalAmount)}
Total repayment amount: ${formatWon(contract.totalRepaymentAmount)}
Due date: ${formatKoreanDate(contract.dueDate)}
Memo: ${contract.memo.isEmpty ? 'none' : contract.memo}

Write one Korean SMS message from the lender to the borrower asking for repayment.
Keep it under 120 Korean characters and make it natural, polite, and specific.
''';
  }

  String _buildFallbackMessage(ContractModel contract) {
    return '${contract.borrowerName}님, ${formatKoreanDate(contract.dueDate)}까지 '
        '${formatWon(contract.totalRepaymentAmount)} 상환 약속이 있어 안내드립니다. '
        '확인 후 가능하실 때 답장 부탁드립니다.';
  }

  String _cleanSmsBody(String value) {
    return value
        .replaceAll(RegExp(r'^["\s]+|["\s]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
