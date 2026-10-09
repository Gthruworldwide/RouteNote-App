import 'package:flutter/foundation.dart';

import '../data/local/settings_repository.dart';
import '../data/models/agent_insight.dart';
import '../data/models/place.dart';
import 'app_health_logger.dart';
import 'gemini_client.dart';
import 'local_insight_engine.dart';

/// Orchestrates the recommendation agent.
///
/// * The **local** [LocalInsightEngine] always runs — instant, offline, private.
/// * The optional **cloud** [GeminiClient] augments it with LLM suggestions when
///   an API key is configured and the user has left cloud AI enabled.
///
/// Only anonymous aggregate metrics are sent to the cloud (see [_metrics]).
class AgentService {
  AgentService({
    required this.logger,
    required this.settings,
    this.engine = const LocalInsightEngine(),
    GeminiClient? cloudClient,
  }) : _cloud = cloudClient ?? GeminiClient();

  final AppHealthLogger logger;
  final SettingsRepository settings;
  final LocalInsightEngine engine;
  final GeminiClient _cloud;

  /// Whether the cloud path can currently run.
  bool get isCloudAvailable => settings.isCloudAiEnabled && _cloud.isConfigured;

  /// Rule-based insights. Always available, never throws.
  List<AgentInsight> localInsights(AgentContext context) =>
      engine.analyze(context);

  /// LLM insights in the user's language. Best-effort: any failure is logged
  /// and returns an empty list so the local insights still stand.
  Future<List<AgentInsight>> cloudInsights(
    AgentContext context, {
    required String languageCode,
    required String languageName,
  }) async {
    if (!settings.isCloudAiEnabled) {
      logger.log(
        HealthEventType.agentSkipped,
        data: const <String, Object?>{'reason': 'disabled'},
      );
      return const <AgentInsight>[];
    }
    if (!_cloud.isConfigured) {
      logger.log(
        HealthEventType.agentSkipped,
        data: const <String, Object?>{'reason': 'not_configured'},
      );
      return const <AgentInsight>[];
    }

    final List<AgentInsight> local = engine.analyze(context);
    try {
      final List<AgentInsight> insights = await _cloud.fetchInsights(
        metrics: _metrics(context, local, languageCode),
        languageName: languageName,
      );
      logger.log(
        HealthEventType.agentRun,
        message: 'cloud',
        data: <String, Object?>{'count': insights.length},
      );
      return insights;
    } on AgentException catch (error) {
      if (kDebugMode) debugPrint('RouteNote agent cloud failure: $error');
      logger.log(HealthEventType.agentFailure, message: error.message);
      return const <AgentInsight>[];
    } catch (error) {
      if (kDebugMode) debugPrint('RouteNote agent cloud failure: $error');
      logger.log(HealthEventType.agentFailure, message: error.toString());
      return const <AgentInsight>[];
    }
  }

  /// Anonymous aggregate metrics — deliberately excludes names, notes, ids and
  /// coordinates so nothing personally identifying ever leaves the device.
  Map<String, Object?> _metrics(
    AgentContext context,
    List<AgentInsight> local,
    String languageCode,
  ) {
    final List<Place> places = context.places;
    final int missingNotes = places
        .where((Place place) => place.notes.trim().isEmpty)
        .length;

    int nearbyClusters = 0;
    int nearbyPlaces = 0;
    for (final AgentInsight insight in local) {
      if (insight.kind == AgentInsightKind.nearbyDuplicates) {
        nearbyClusters = (insight.params['clusters'] as int?) ?? 0;
        nearbyPlaces = (insight.params['count'] as int?) ?? 0;
      }
    }

    final DateTime? lastSynced = context.lastSynced?.toUtc();
    final int? lastBackupDaysAgo = lastSynced == null
        ? null
        : ((context.now ?? DateTime.now()).toUtc().difference(lastSynced).inDays);

    return <String, Object?>{
      'language': languageCode,
      'savedPlaces': places.length,
      'pinnedPlaces': places.where((Place p) => p.isPinned).length,
      'hiddenPlaces': places.where((Place p) => p.isHidden).length,
      'lockedPlaces': places.where((Place p) => p.isLocked).length,
      'placesWithoutNotes': missingNotes,
      'nearbyClusters': nearbyClusters,
      'nearbyPlaces': nearbyPlaces,
      'signedIn': context.isSignedIn,
      'lastBackupDaysAgo': lastBackupDaysAgo,
      'recentSyncFailures': context.health.syncFailed,
      'recentSyncSuccesses': context.health.syncSucceeded,
      'recentSyncSkipped': context.health.syncSkipped,
      'parseFailures': context.health.parseFailures,
      'shortLinkFailures': context.health.shortLinkFailures,
      'appLaunches': context.health.appLaunches,
    };
  }
}
