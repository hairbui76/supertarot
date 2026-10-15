import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supertarot_mobile/src/data/settings_store.dart';
import 'package:supertarot_mobile/src/services/llm_client.dart';

http.Response _anthropicOk() => http.Response.bytes(
      utf8.encode(
        jsonEncode(<String, dynamic>{
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'thinking', 'thinking': ''},
            <String, dynamic>{'type': 'text', 'text': 'ok'},
          ],
          'stop_reason': 'end_turn',
        }),
      ),
      200,
    );

Future<String> _call(LlmClient client, String model) => client.complete(
      provider: LlmProvider.anthropic,
      model: model,
      apiKey: 'test',
      systemPrompt: 'system',
      userPrompt: 'user',
      temperature: 0.2,
    );

void main() {
  group('supportsTemperature', () {
    const Map<String, bool> anthropic = <String, bool>{
      'claude-opus-5-5': false,
      'claude-opus-5': false,
      'claude-opus-4-7': false,
      'claude-sonnet-5-5': false,
      'claude-haiku-5-5': false,
      'claude-fable-5-1': false,
      'claude-opus-4-6': true,
      'claude-sonnet-4-6': true,
      'claude-haiku-4-5-20251001': true,
      'claude-sonnet-4-20250514': true,
      'claude-3-5-sonnet-latest': true,
    };
    anthropic.forEach((String model, bool expected) {
      test('anthropic $model -> $expected', () {
        expect(
          LlmClient.supportsTemperature(LlmProvider.anthropic, model),
          expected,
        );
      });
    });

    test('openai reasoning models use the default temperature', () {
      expect(
        LlmClient.supportsTemperature(LlmProvider.openai, 'gpt-4.1-mini'),
        isTrue,
      );
      expect(
        LlmClient.supportsTemperature(LlmProvider.openai, 'gpt-5-mini'),
        isFalse,
      );
      expect(
        LlmClient.supportsTemperature(LlmProvider.openai, 'o4-mini'),
        isFalse,
      );
    });
  });

  test('omits temperature for claude-opus-5-5', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    final LlmClient client = LlmClient(
      httpClient: MockClient((http.Request request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _anthropicOk();
      }),
    );

    expect(await _call(client, 'claude-opus-5-5'), 'ok');
    expect(bodies, hasLength(1));
    expect(bodies.single.containsKey('temperature'), isFalse);
  });

  test(
    'retries without temperature when an unknown model rejects it',
    () async {
      final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
      final LlmClient client = LlmClient(
        httpClient: MockClient((http.Request request) async {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          if (body.containsKey('temperature')) {
            return http.Response(
              '{"type":"error","error":{"type":"invalid_request_error",'
              '"message":"temperature is deprecated for this model."}}',
              400,
            );
          }
          return _anthropicOk();
        }),
      );

      expect(await _call(client, 'claude-future-model'), 'ok');
      expect(bodies, hasLength(2));
      expect(bodies.first['temperature'], 0.2);
      expect(bodies.last.containsKey('temperature'), isFalse);
    },
  );
}
