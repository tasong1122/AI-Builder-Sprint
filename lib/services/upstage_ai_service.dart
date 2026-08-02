import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/contract_model.dart';
import '../widgets/contract_card.dart';

class UpstageAiService {
  UpstageAiService({
    http.Client? client,
    String? apiKey,
    String? endpoint,
    String? model,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? const String.fromEnvironment('UPSTAGE_API_KEY'),
       _endpoint =
           endpoint ??
           const String.fromEnvironment(
             'UPSTAGE_CHAT_ENDPOINT',
             defaultValue: 'https://api.upstage.ai/v1/solar/chat/completions',
           ),
       _model =
           model ??
           const String.fromEnvironment(
             'UPSTAGE_CHAT_MODEL',
             defaultValue: 'solar-pro2',
           );

  final http.Client _client;
  final String _apiKey;
  final String _endpoint;
  final String _model;

  // 돈 약속 상세 정보를 기반으로 Upstage API에 독촉문구 생성을 요청한다.
  Future<String> generateReminderMessage({
    required ContractModel contract,
    required String senderName,
    required String recipientName,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw StateError('UPSTAGE_API_KEY가 설정되지 않았습니다.');
    }

    final interestRateText =
        contract.interestRate == contract.interestRate.roundToDouble()
        ? contract.interestRate.toInt().toString()
        : contract.interestRate.toString();
    final dueDate = formatKoreanDate(contract.dueDate);
    final memoText = contract.memo.isEmpty ? '없음' : contract.memo;

    final userPrompt =
        '''
다음 돈 약속 정보를 바탕으로 한국어 독촉 메세지를 작성해 줘.
친근하지만 예의 있는 톤으로 7~10줄 내외로 작성해 줘.
불필요한 설명 없이 바로 보낼 수 있는 메세지 본문만 출력해 줘.

[돈 약속 정보]
받는 사람: $recipientName
보내는 사람: $senderName
빌려주는 사람: ${contract.lenderName}
빌리는 사람: ${contract.borrowerName}
빌린 금액: ${formatWon(contract.principalAmount)}
갚을 날짜: $dueDate
이자율: ${contract.interestRate > 0 ? '$interestRateText%' : '없음'}
이자 금액: ${contract.interestAmount > 0 ? formatWon(contract.interestAmount) : '없음'}
총 갚을 금액: ${formatWon(contract.totalRepaymentAmount)}
메모: $memoText
''';

    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You write clear, polite Korean repayment reminder messages.',
              },
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.6,
            'max_tokens': 500,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Upstage API 요청에 실패했습니다. (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Upstage 응답 형식이 올바르지 않습니다.');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Upstage 응답에서 생성 결과를 찾을 수 없습니다.');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      throw const FormatException('Upstage 응답 형식이 올바르지 않습니다.');
    }

    final message = firstChoice['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('Upstage 응답 형식이 올바르지 않습니다.');
    }

    final content = message['content'];
    final generatedText = _extractContentText(content).trim();
    if (generatedText.isEmpty) {
      throw const FormatException('Upstage 응답이 비어 있습니다.');
    }
    return generatedText;
  }

  // OpenAI 호환 응답 content를 문자열로 정규화한다.
  String _extractContentText(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      final textParts = <String>[];
      for (final item in content) {
        if (item is Map<String, dynamic>) {
          final text = item['text'];
          if (text is String && text.trim().isNotEmpty) {
            textParts.add(text.trim());
          }
        }
      }
      return textParts.join('\n').trim();
    }
    return '';
  }
}
