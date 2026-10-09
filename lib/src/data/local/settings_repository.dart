import 'package:hive_ce/hive.dart';

/// Small key/value store for app preferences backed by a Hive box.
class SettingsRepository {
  SettingsRepository(this._box);

  final Box<dynamic> _box;

  static const String _localeKey = 'locale';
  static const String _themeModeKey = 'theme_mode';
  static const String _lastSyncedKey = 'last_synced';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _authUserKey = 'auth_user';
  static const String _cloudAiKey = 'cloud_ai_enabled';
  static const String _dismissedInsightsKey = 'dismissed_insights';

  /// BCP-47 language code of the selected locale, or null for system default.
  String? get localeCode => _box.get(_localeKey) as String?;

  Future<void> setLocaleCode(String? code) async {
    if (code == null || code.isEmpty) {
      await _box.delete(_localeKey);
    } else {
      await _box.put(_localeKey, code);
    }
  }

  int? get themeModeIndex => _box.get(_themeModeKey) as int?;

  Future<void> setThemeModeIndex(int index) async {
    await _box.put(_themeModeKey, index);
  }

  DateTime? get lastSynced {
    final Object? raw = _box.get(_lastSyncedKey);
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    return null;
  }

  Future<void> setLastSynced(DateTime time) async {
    await _box.put(_lastSyncedKey, time.toUtc().toIso8601String());
  }

  /// Whether a Google session was active the last time the app ran.
  ///
  /// This is the *local* mirror of the remote session, used to render the
  /// signed-in UI on the first frame instead of a "Signing in..." loader.
  bool get isLoggedIn => _box.get(_isLoggedInKey) == true;

  /// The cached profile of the signed-in user, or null when none is stored.
  Map<String, dynamic>? get authUser {
    final Object? raw = _box.get(_authUserKey);
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Persists the cached Google session (or clears it when [user] is null) so
  /// launch can render the signed-in state without waiting on the network.
  Future<void> saveAuthSession(Map<String, dynamic>? user) async {
    await _box.put(_isLoggedInKey, user != null);
    if (user == null) {
      await _box.delete(_authUserKey);
    } else {
      await _box.put(_authUserKey, user);
    }
  }

  /// Whether optional cloud (Gemini) recommendations are allowed.
  ///
  /// Defaults to true so the feature works once an API key is compiled in; the
  /// user can switch it off in Settings to keep everything local.
  bool get isCloudAiEnabled => (_box.get(_cloudAiKey) as bool?) ?? true;

  Future<void> setCloudAiEnabled(bool enabled) async {
    await _box.put(_cloudAiKey, enabled);
  }

  /// Stable ids of insights the user has dismissed, so the agent stops
  /// nagging across launches.
  List<String> get dismissedInsightIds {
    final Object? raw = _box.get(_dismissedInsightsKey);
    if (raw is! List) return const <String>[];
    return raw.whereType<String>().toList(growable: false);
  }

  /// Remembers a dismissed insight, keeping the list bounded.
  Future<void> dismissInsight(String id) async {
    final List<String> ids = dismissedInsightIds.toList();
    if (!ids.contains(id)) ids.add(id);
    const int maxDismissed = 100;
    if (ids.length > maxDismissed) {
      ids.removeRange(0, ids.length - maxDismissed);
    }
    await _box.put(_dismissedInsightsKey, ids);
  }

  Future<void> clearDismissedInsights() async {
    await _box.delete(_dismissedInsightsKey);
  }
}
