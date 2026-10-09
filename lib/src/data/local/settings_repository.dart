import 'package:hive_ce/hive.dart';

/// Small key/value store for app preferences backed by a Hive box.
class SettingsRepository {
  SettingsRepository(this._box);

  final Box<dynamic> _box;

  static const String _localeKey = 'locale';
  static const String _themeModeKey = 'theme_mode';
  static const String _lastSyncedKey = 'last_synced';

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
}
