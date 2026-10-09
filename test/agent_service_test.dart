import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:routenote/src/data/local/settings_repository.dart';
import 'package:routenote/src/data/models/agent_insight.dart';
import 'package:routenote/src/data/models/place.dart';
import 'package:routenote/src/services/agent_service.dart';
import 'package:routenote/src/services/app_health_logger.dart';
import 'package:routenote/src/services/gemini_client.dart';
import 'package:routenote/src/services/local_insight_engine.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late SettingsRepository settings;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('routenote_agent_');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('agent_test');
    settings = SettingsRepository(box);
  });

  tearDown(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('cloud insights send only anonymous aggregate metrics', () async {
    String? capturedText;
    final MockClient mock = MockClient((http.Request request) async {
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      final List<dynamic> contents = body['contents'] as List<dynamic>;
      final Map<String, dynamic> content =
          contents.first as Map<String, dynamic>;
      final List<dynamic> parts = content['parts'] as List<dynamic>;
      final Map<String, dynamic> part = parts.first as Map<String, dynamic>;
      capturedText = part['text'] as String;
      return http.Response(
        jsonEncode(<String, Object?>{
          'candidates': <Object?>[
            <String, Object?>{
              'content': <String, Object?>{
                'parts': <Object?>[
                  <String, Object?>{
                    'text': jsonEncode(<Map<String, String>>[
                      <String, String>{
                        'title': 'Tidy up',
                        'body': 'You have places without notes.',
                        'severity': 'info',
                      },
                    ]),
                  },
                ],
              },
            },
          ],
        }),
        200,
      );
    });

    final AppHealthLogger logger = AppHealthLogger(box);
    final AgentService service = AgentService(
      logger: logger,
      settings: settings,
      cloudClient: GeminiClient(apiKey: 'test-key', client: mock),
    );

    final AgentContext context = AgentContext(
      places: <Place>[
        Place(
          id: 'p1',
          name: 'Secret Villa',
          notes: 'private note',
          latitude: 30.0444,
          longitude: 31.2357,
          timestamp: DateTime.utc(2026, 1, 1),
        ),
      ],
      health: HealthSummary.empty,
    );

    final List<AgentInsight> insights = await service.cloudInsights(
      context,
      languageCode: 'en',
      languageName: 'English',
    );

    expect(insights, hasLength(1));
    expect(insights.single.customTitle, 'Tidy up');

    // No personally identifying data leaves the device.
    expect(capturedText, isNotNull);
    expect(capturedText, isNot(contains('Secret Villa')));
    expect(capturedText, isNot(contains('private note')));
    expect(capturedText, isNot(contains('30.0444')));
    expect(capturedText, contains('savedPlaces'));

    expect(logger.count(HealthEventType.agentRun), 1);
  });

  test('cloud is skipped when the user turns it off', () async {
    await settings.setCloudAiEnabled(false);

    bool called = false;
    final AgentService service = AgentService(
      logger: AppHealthLogger(box),
      settings: settings,
      cloudClient: GeminiClient(
        apiKey: 'test-key',
        client: MockClient((http.Request request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      ),
    );

    final List<AgentInsight> insights = await service.cloudInsights(
      const AgentContext(places: <Place>[], health: HealthSummary.empty),
      languageCode: 'en',
      languageName: 'English',
    );

    expect(insights, isEmpty);
    expect(called, isFalse);
    expect(service.isCloudAvailable, isFalse);
  });

  test('local insights are always available without a key', () {
    final AgentService service = AgentService(
      logger: AppHealthLogger(box),
      settings: settings,
      cloudClient: GeminiClient(apiKey: ''),
    );

    final List<AgentInsight> insights = service.localInsights(
      const AgentContext(places: <Place>[], health: HealthSummary.empty),
    );

    expect(insights, hasLength(1));
    expect(insights.single.kind, AgentInsightKind.welcome);
    expect(service.isCloudAvailable, isFalse);
  });
}
