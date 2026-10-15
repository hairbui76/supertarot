import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/settings_store.dart';

/// Raised when a provider call fails in a way worth showing to the user.
class LlmException implements Exception {
  LlmException(this.message, {this.statusCode, this.body = ''});

  final String message;
  final int? statusCode;
  final String body;

  /// The provider refused the request because of a sampling parameter, e.g.
  /// "temperature is deprecated for this model" on newer Claude models.
  bool get rejectsTemperature =>
      statusCode == 400 && body.toLowerCase().contains('temperature');

  @override
  String toString() => message;
}

/// Direct REST adapters for OpenAI, Anthropic and Google, mirroring
/// `app/llm.py`. The app talks to the vendors with the key the user typed in
/// Settings; there is no SuperTarot server in between.
class LlmClient {
  LlmClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        // Newer models always think before answering, so a multi-card reading
        // can take well over a minute.
        _timeout = const Duration(seconds: 180);

  final http.Client _http;
  final Duration _timeout;

  /// [temperature] is a preference, not a requirement: it is dropped for
  /// models that reject sampling parameters, and the request is retried
  /// without it if the provider still complains.
  Future<String> complete({
    required LlmProvider provider,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    bool jsonMode = false,
  }) async {
    final double? sent =
        supportsTemperature(provider, model) ? temperature : null;
    try {
      return await _complete(
        provider: provider,
        model: model,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: sent,
        jsonMode: jsonMode,
      );
    } on LlmException catch (error) {
      if (sent == null || !error.rejectsTemperature) {
        rethrow;
      }
      return _complete(
        provider: provider,
        model: model,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: null,
        jsonMode: jsonMode,
      );
    }
  }

  /// Whether [model] still accepts a custom `temperature`.
  ///
  /// Claude Opus 4.7+, Sonnet 5+, Haiku 5+ and Fable/Mythos return 400 for
  /// sampling parameters; OpenAI reasoning models (o-series, gpt-5) only
  /// accept the default.
  static bool supportsTemperature(LlmProvider provider, String model) {
    final String id = model.trim().toLowerCase();
    switch (provider) {
      case LlmProvider.anthropic:
        if (RegExp(r'claude-(fable|mythos)').hasMatch(id)) {
          return false;
        }
        final RegExpMatch? match =
            RegExp(r'claude-(opus|sonnet|haiku)-(\d+)(?:-(\d{1,2})(?=-|@|$))?')
                .firstMatch(id);
        if (match == null) {
          return true;
        }
        final int major = int.parse(match.group(2)!);
        final int minor = int.tryParse(match.group(3) ?? '') ?? 0;
        if (match.group(1) == 'opus') {
          return major < 4 || (major == 4 && minor < 7);
        }
        return major < 5;
      case LlmProvider.openai:
        return !RegExp(r'^(o\d|gpt-5)').hasMatch(id);
      case LlmProvider.google:
      case LlmProvider.auto:
        return true;
    }
  }

  Future<String> _complete({
    required LlmProvider provider,
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double? temperature,
    required bool jsonMode,
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
    required double? temperature,
    required bool jsonMode,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'model': model,
      'messages': <Map<String, String>>[
        <String, String>{'role': 'system', 'content': systemPrompt},
        <String, String>{'role': 'user', 'content': userPrompt},
      ],
      if (temperature != null) 'temperature': temperature,
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
    required double? temperature,
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
        // Thinking tokens count against max_tokens on models that always think.
        'max_tokens': 16000,
        if (temperature != null) 'temperature': temperature,
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
    final String text = parts.join('\n').trim();
    if (text.isEmpty && data['stop_reason'] == 'refusal') {
      throw LlmException('Anthropic declined this request (refusal).');
    }
    return text;
  }

  Future<String> _google({
    required String model,
    required String apiKey,
    required String systemPrompt,
    required String userPrompt,
    required double? temperature,
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
          if (temperature != null) 'temperature': temperature,
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
      final String body =
          utf8.decode(response.bodyBytes, allowMalformed: true);
      throw LlmException(
        '$providerLabel returned ${response.statusCode}: ${_shorten(body)}',
        statusCode: response.statusCode,
        body: body,
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
