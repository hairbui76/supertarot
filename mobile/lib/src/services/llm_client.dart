import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/settings_store.dart';

/// Raised when a provider call fails in a way worth showing to the user.
class LlmException implements Exception {
  LlmException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Direct REST adapters for OpenAI, Anthropic and Google, mirroring
/// `app/llm.py`. The app talks to the vendors with the key the user typed in
/// Settings; there is no SuperTarot server in between.
class LlmClient {
  LlmClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _timeout = const Duration(seconds: 90);

  final http.Client _http;
  final Duration _timeout;

  Future<String> complete({
    required LlmProvider provider,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    bool jsonMode = false,
  }) {
    switch (provider) {
      case LlmProvider.openai:
        return _openai(
          model: model,
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          temperature: temperature,
          jsonMode: jsonMode,
        );
      case LlmProvider.anthropic:
        return _anthropic(
          model: model,
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          temperature: temperature,
        );
      case LlmProvider.google:
        return _google(
          model: model,
          apiKey: apiKey,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          temperature: temperature,
          jsonMode: jsonMode,
        );
      case LlmProvider.auto:
        throw LlmException('Provider "auto" must be resolved before calling.');
    }
  }

  Future<String> _openai({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required bool jsonMode,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'model': model,
      'messages': <Map<String, String>>[
        <String, String>{'role': 'system', 'content': systemPrompt},
        <String, String>{'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      if (jsonMode)
        'response_format': <String, String>{'type': 'json_object'},
    };

    final http.Response response = await _post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: payload,
      providerLabel: 'OpenAI',
    );

    final Map<String, dynamic> data = _decode(response);
    final List<dynamic> choices = data['choices'] as List<dynamic>? ?? const <dynamic>[];
    if (choices.isEmpty) {
      throw LlmException('OpenAI returned no choices.');
    }
    final Map<String, dynamic> message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>;
    return (message['content'] as String? ?? '').trim();
  }

  Future<String> _anthropic({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
  }) async {
    final http.Response response = await _post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: <String, String>{
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: <String, dynamic>{
        'model': model,
        'max_tokens': 4096,
        'temperature': temperature,
        'system': systemPrompt,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'user', 'content': userPrompt},
        ],
      },
      providerLabel: 'Anthropic',
    );

    final Map<String, dynamic> data = _decode(response);
    final List<dynamic> blocks =
        data['content'] as List<dynamic>? ?? const <dynamic>[];
    final List<String> parts = <String>[
      for (final dynamic block in blocks)
        if ((block as Map<String, dynamic>)['text'] is String)
          block['text'] as String,
    ];
    return parts.join('\n').trim();
  }

  Future<String> _google({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required bool jsonMode,
  }) async {
    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent',
    );

    final http.Response response = await _post(
      uri,
      headers: <String, String>{
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: <String, dynamic>{
        'systemInstruction': <String, dynamic>{
          'parts': <Map<String, String>>[
            <String, String>{'text': systemPrompt},
          ],
        },
        'contents': <Map<String, dynamic>>[
          <String, dynamic>{
            'role': 'user',
            'parts': <Map<String, String>>[
              <String, String>{'text': userPrompt},
            ],
          },
        ],
        'generationConfig': <String, dynamic>{
          'temperature': temperature,
          if (jsonMode) 'responseMimeType': 'application/json',
        },
      },
      providerLabel: 'Google',
    );

    final Map<String, dynamic> data = _decode(response);
    final List<dynamic> candidates =
        data['candidates'] as List<dynamic>? ?? const <dynamic>[];
    if (candidates.isEmpty) {
      throw LlmException('Google returned no candidates.');
    }
    final Map<String, dynamic> content =
        (candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>;
    final List<dynamic> parts =
        content['parts'] as List<dynamic>? ?? const <dynamic>[];
    return parts
        .map((dynamic part) =>
            (part as Map<String, dynamic>)['text'] as String? ?? '')
        .join('\n')
        .trim();
  }

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required String providerLabel,
  }) async {
    final http.Response response;
    try {
      response = await _http
          .post(uri, headers: headers, body: utf8.encode(jsonEncode(body)))
          .timeout(_timeout);
    } on Exception catch (error) {
      throw LlmException('$providerLabel request failed: $error');
    }

    if (response.statusCode >= 400) {
      throw LlmException(
        '$providerLabel returned ${response.statusCode}: '
        '${_shorten(utf8.decode(response.bodyBytes, allowMalformed: true))}',
      );
    }
    return response;
  }

  /// `http.Response.body` falls back to latin1 when the server omits a
  /// charset, which mangles Vietnamese. Always decode the raw bytes as UTF-8.
  static Map<String, dynamic> _decode(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

  static String _shorten(String value) {
    final String collapsed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length <= 300
        ? collapsed
        : '${collapsed.substring(0, 299)}…';
  }
}
