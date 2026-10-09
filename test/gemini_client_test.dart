import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:routenote/src/data/models/agent_insight.dart';
import 'package:routenote/src/services/gemini_client.dart';

http.Response _responseWith(List<Map<String, String>> suggestions) {
  final String inner = jsonEncode(suggestions);
  final Map<String, Object?> body = <String, Object?>{
    'candidates': <Object?>[
      <String, Object?>{
        'content': <String, Object?>{
          'parts': <Object?>[
            <String, Object?>{'text': inner},
          ],
        },
      },
    ],
  };
  return http.Response(jsonEncode(body), 200);
}

void main() {
  test('parses localized suggestions from a Gemini response', () async {
    final GeminiClient client = GeminiClient(
      apiKey: 'test-key',
      client: MockClient(
        (http.Request request) async => _responseWith(<Map<String, String>>[
          <String, String>{
            'title': 'Group nearby places',
            'body': 'Two saved places overlap.',
            'severity': 'suggestion',
          },
          <String, String>{
            'title': 'Back up now',
            'body': 'Your last backup is old.',
            'severity': 'warning',
          },
        ]),
      ),
    );

    expect(client.isConfigured, isTrue);
    final List<AgentInsight> insights = await client.fetchInsights(
      metrics: const <String, Object?>{'savedPlaces': 3},
      languageName: 'English',
    );

    expect(insights, hasLength(2));
    expect(insights.first.kind, AgentInsightKind.custom);
    expect(insights.first.customTitle, 'Group nearby places');
    expect(insights.first.customBody, 'Two saved places overlap.');
    expect(insights[1].severity, AgentInsightSeverity.warning);
  });

  test('sends the API key in a header, never in the URL', () async {
    late http.Request captured;
    final GeminiClient client = GeminiClient(
      apiKey: 'secret-key',
      client: MockClient((http.Request request) async {
        captured = request;
        return _responseWith(const <Map<String, String>>[]);
      }),
    );

    await client.fetchInsights(
      metrics: const <String, Object?>{},
      languageName: 'English',
    );

    expect(captured.headers['x-goog-api-key'], 'secret-key');
    expect(captured.url.query.contains('secret-key'), isFalse);
    expect(captured.url.queryParameters.containsKey('key'), isFalse);
  });

  test('never surfaces the raw transport error (which could embed the URL)',
      () async {
    final GeminiClient client = GeminiClient(
      apiKey: 'secret-key',
      client: MockClient((http.Request request) async {
        throw http.ClientException(
          'failed to connect to ${request.url}',
          request.url,
        );
      }),
    );

    await expectLater(
      () => client.fetchInsights(
        metrics: const <String, Object?>{},
        languageName: 'English',
      ),
      throwsA(
        isA<AgentException>().having(
          (AgentException e) => e.message,
          'message',
          isNot(contains('secret-key')),
        ),
      ),
    );
  });

  test('strips markdown code fences from the response', () async {
    final GeminiClient client = GeminiClient(
      apiKey: 'test-key',
      client: MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, Object?>{
            'candidates': <Object?>[
              <String, Object?>{
                'content': <String, Object?>{
                  'parts': <Object?>[
                    <String, Object?>{
                      'text':
                          '```json\n'
                          '[{"title":"T","body":"B","severity":"info"}]\n'
                          '```',
                    },
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );

    final List<AgentInsight> insights = await client.fetchInsights(
      metrics: const <String, Object?>{},
      languageName: 'English',
    );
    expect(insights, hasLength(1));
    expect(insights.single.severity, AgentInsightSeverity.info);
  });

  test('returns an empty list when no key is configured', () async {
    final GeminiClient client = GeminiClient(
      apiKey: '',
      client: MockClient(
        (http.Request request) async => http.Response('{}', 200),
      ),
    );
    expect(client.isConfigured, isFalse);
    expect(
      await client.fetchInsights(
        metrics: const <String, Object?>{},
        languageName: 'English',
      ),
      isEmpty,
    );
  });

  test('throws AgentException on an HTTP failure', () async {
    final GeminiClient client = GeminiClient(
      apiKey: 'test-key',
      client: MockClient(
        (http.Request request) async => http.Response('nope', 500),
      ),
    );
    expect(
      () => client.fetchInsights(
        metrics: const <String, Object?>{},
        languageName: 'English',
      ),
      throwsA(isA<AgentException>()),
    );
  });
}
