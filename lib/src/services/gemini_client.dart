import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../data/models/agent_insight.dart';

/// Raised when a cloud recommendation request fails.
class AgentException implements Exception {
  const AgentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin client for Google's Gemini `generateContent` REST API.
///
/// This is intentionally optional: when no API key is configured it reports
/// [isConfigured] = false and the app stays fully offline-first. Only anonymous
/// aggregate [metrics] are ever sent — never place names, notes or coordinates.
class GeminiClient {
  GeminiClient({
    http.Client? client,
    String? apiKey,
    String? model,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? AppConfig.geminiApiKey,
       _model = (model ?? AppConfig.geminiModel).trim(),
       _timeout = timeout ?? AppConfig.agentRequestTimeout;

  final http.Client _client;
  final String _apiKey;
  final String _model;
  final Duration _timeout;

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Asks Gemini for up to [AppConfig.maxAgentInsights] localized suggestions.
  ///
  /// [languageName] is the human-readable language for the response (e.g.
  /// "English" or "Arabic") so insights arrive already localized.
  Future<List<AgentInsight>> fetchInsights({
    required Map<String, Object?> metrics,
    required String languageName,
  }) async {
    if (!isConfigured) return const <AgentInsight>[];

    final Uri uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
    );

    final Map<String, Object?> body = <String, Object?>{
      'systemInstruction': <String, Object?>{
        'parts': <Object?>[
          <String, Object?>{
            'text':
                'You are the in-app assistant of "RouteNote", an offline-first '
                'location saving app. You receive anonymous aggregate metrics '
                'about the user\'s local data and app health. Respond ONLY with '
                'a JSON array (no markdown, no prose) of at most '
                '${AppConfig.maxAgentInsights} objects. Each object must have '
                'exactly these string keys: "title" (max 6 words), "body" '
                '(max 20 words), and "severity" (one of "info", "suggestion", '
                '"warning"). Give concrete, friendly, non-repetitive tips about '
                'organizing locations, sync/network reliability, or app speed. '
                'Never invent data or mention that you are an AI.',
          },
        ],
      },
      'contents': <Object?>[
        <String, Object?>{
          'role': 'user',
          'parts': <Object?>[
            <String, Object?>{
              'text':
                  'Language for the response: $languageName.\n'
                  'Anonymous metrics JSON:\n${jsonEncode(metrics)}',
            },
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'temperature': 0.4,
        'maxOutputTokens': 512,
        'responseMimeType': 'application/json',
      },
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              // The key travels in a header, never the URL, so it can't leak
              // through request URIs embedded in error messages or logs.
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AgentException('Cloud suggestions timed out');
    } catch (_) {
      // Deliberately opaque: a raw transport error can embed the request URI
      // and headers. Never surface it.
      throw const AgentException('Cloud suggestions unavailable');
    }

    if (response.statusCode != 200) {
      throw AgentException(
        'Cloud suggestions failed (HTTP ${response.statusCode})',
      );
    }

    return _parse(response.body);
  }

  List<AgentInsight> _parse(String rawBody) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawBody);
    } catch (_) {
      throw const AgentException('Cloud suggestions returned invalid JSON');
    }
    if (decoded is! Map) {
      throw const AgentException('Cloud suggestions returned an unexpected body');
    }

    final Object? candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AgentException('Cloud suggestions returned no candidates');
    }

    final String? text = _extractText(candidates.first);
    if (text == null) {
      return const <AgentInsight>[];
    }
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const <AgentInsight>[];
    }

    final Object? parsed = jsonDecode(_stripCodeFences(trimmed));
    if (parsed is! List) {
      throw const AgentException('Cloud suggestions were not a JSON array');
    }

    final List<AgentInsight> insights = <AgentInsight>[];
    for (final Object? item in parsed) {
      if (item is! Map) continue;
      final String title = _clean(item['title'] is String ? item['title'] as String : item['title']);
      final String body = _clean(item['body'] is String ? item['body'] as String : item['body']);
      if (title.isEmpty || body.isEmpty) continue;
      insights.add(
        AgentInsight(
          id: 'llm-${title.hashCode}',
          kind: AgentInsightKind.custom,
          severity: _severity(item['severity']),
          customTitle: title,
          customBody: body,
        ),
      );
      if (insights.length >= AppConfig.maxAgentInsights) break;
    }
    return insights;
  }

  String? _extractText(Object? candidate) {
    if (candidate is! Map) return null;
    final Object? content = candidate['content'];
    if (content is! Map) return null;
    final Object? parts = content['parts'];
    if (parts is! List) return null;
    final StringBuffer buffer = StringBuffer();
    for (final Object? part in parts) {
      if (part is Map && part['text'] != null) {
        buffer.write(part['text']);
      }
    }
    return buffer.toString();
  }

  static String _stripCodeFences(String value) {
    String text = value.trim();
    if (text.startsWith('```')) {
      final int firstNewline = text.indexOf('\n');
      if (firstNewline != -1) text = text.substring(firstNewline + 1);
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
    }
    return text.trim();
  }

  static AgentInsightSeverity _severity(Object? raw) {
    return switch (raw?.toString().toLowerCase()) {
      'warning' => AgentInsightSeverity.warning,
      'info' => AgentInsightSeverity.info,
      _ => AgentInsightSeverity.suggestion,
    };
  }

  static String _clean(Object? raw) {
    if (raw == null) return '';
    final String text = raw.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length > 200 ? text.substring(0, 200) : text;
  }

  /// Releases the underlying HTTP client.
  void close() => _client.close();
}
