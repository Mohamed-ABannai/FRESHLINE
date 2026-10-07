import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class GroqMessage {
  const GroqMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() {
    return <String, String>{'role': role, 'content': content};
  }
}

class GroqService {
  GroqService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> chat({
    required List<GroqMessage> history,
    required String languageHint,
    required String systemPrompt,
  }) async {
    final Uri uri = Uri.parse(
      'https://api.groq.com/openai/v1/chat/completions',
    );

    final http.Response response = await _client.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $groqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, Object>{
        'model': groqModel,
        'temperature': 0.7,
        'messages': <Map<String, String>>[
          <String, String>{
            'role': 'system',
            'content':
                '$systemPrompt '
                'Respond in the same language as the user\'s most recent message. '
                'If the user mixes languages, respond in the language used in their last sentence. '
                'If you are not sure which language to use, respond in $languageHint. '
                'Do not mix languages or provide translations unless the user asks. '
                'Keep answers concise, helpful, and specific to the Freshline app context.',
          },
          ...history.map((GroqMessage message) => message.toJson()),
        ],
      }),
    );

    final Object? payload = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        payload is Map<String, dynamic>
            ? ((payload['error'] as Map<String, dynamic>?)?['message']
                      as String?) ??
                  'Groq request failed.'
            : 'Groq request failed.',
      );
    }

    if (payload is! Map<String, dynamic>) {
      throw Exception('Unexpected Groq response.');
    }

    final List<dynamic> choices =
        payload['choices'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic>? message = choices.isNotEmpty
        ? choices.first['message'] as Map<String, dynamic>?
        : null;
    final String content = (message?['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) {
      throw Exception('Empty AI response.');
    }

    return content;
  }

  void dispose() {
    _client.close();
  }
}
