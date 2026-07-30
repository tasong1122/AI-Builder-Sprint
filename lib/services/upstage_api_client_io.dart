import 'dart:convert';
import 'dart:io';

class UpstageApiClient {
  UpstageApiClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  // Sends the reminder prompt to the Solar chat completion endpoint.
  Future<String> createReminderMessage({
    required String apiKey,
    required String prompt,
  }) async {
    final request = await _httpClient.postUrl(
      Uri.parse('https://api.upstage.ai/v1/solar/chat/completions'),
    );
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
      ..set(HttpHeaders.contentTypeHeader, ContentType.json.mimeType);
    request.write(
      jsonEncode({
        'model': 'solar-pro',
        'messages': [
          {
            'role': 'system',
            'content':
                'You write concise, polite Korean SMS reminder messages for repayment. '
                'Do not include threats, shame, legal claims, or private identifiers.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.4,
        'max_tokens': 180,
      }),
    );

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Upstage API request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(responseBody);
    final choices = decoded is Map<String, dynamic> ? decoded['choices'] : null;
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('Upstage API response has no choices.');
    }

    final firstChoice = choices.first;
    final message = firstChoice is Map<String, dynamic>
        ? firstChoice['message']
        : null;
    final content = message is Map<String, dynamic> ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('Upstage API response has no message.');
    }

    return content;
  }
}
