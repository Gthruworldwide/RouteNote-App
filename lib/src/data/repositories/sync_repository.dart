import 'dart:convert';

import '../local/settings_repository.dart';
import '../models/backup_data.dart';
import '../models/place.dart';
import '../remote/auth_service.dart';
import '../remote/drive_service.dart';
import 'place_repository.dart';

/// Result of a sync attempt.
enum SyncOutcome {
  /// No Google account, nothing was (and could be) done.
  skippedNotSignedIn,

  /// Local data overwrote the Drive backup (the WhatsApp model: device wins).
  uploaded,

  /// Device was empty, the Drive backup was restored into local storage.
  restored,
}

/// Orchestrates the local database <-> Google Drive backup flows.
///
/// Policy (matches the product spec):
/// * On launch: if the device has data it *overrides* the Drive backup.
/// * On a fresh device (empty local DB) with an existing backup, the backup is
///   restored into the local database.
/// * There is exactly one JSON file in the Drive app-data folder.
class SyncRepository {
  SyncRepository({
    required PlaceRepository placeRepository,
    required DriveService driveService,
    required SettingsRepository settingsRepository,
    required AuthService authService,
  }) : _places = placeRepository,
       _drive = driveService,
       _settings = settingsRepository,
       _auth = authService;

  final PlaceRepository _places;
  final DriveService _drive;
  final SettingsRepository _settings;
  final AuthService _auth;

  /// Runs the "sync on open" flow described above.
  Future<SyncOutcome> syncNow() async {
    if (!_auth.isSignedIn) return SyncOutcome.skippedNotSignedIn;

    final List<Place> local = await _places.getAll();
    if (local.isEmpty && await _drive.backupExists()) {
      await restoreFromDrive();
      return SyncOutcome.restored;
    }
    await backupToDrive();
    return SyncOutcome.uploaded;
  }

  /// Serializes the local database to JSON and overwrites the Drive backup.
  Future<void> backupToDrive() async {
    final List<Place> local = await _places.getAll();
    final DateTime now = DateTime.now().toUtc();
    final BackupData data = BackupData(lastSynced: now, places: local);
    await _drive.uploadBackup(jsonEncode(data.toJson()));
    await _settings.setLastSynced(now);
  }

  /// Downloads the Drive backup and replaces local data. Returns the number of
  /// restored places.
  Future<int> restoreFromDrive() async {
    final String? raw = await _drive.downloadBackup();
    if (raw == null || raw.isEmpty) return 0;

    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException(
        'Google Drive backup is not a valid JSON object',
      );
    }

    final BackupData data = BackupData.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    await _places.replaceAll(data.places);
    await _settings.setLastSynced(data.lastSynced ?? DateTime.now().toUtc());
    return data.places.length;
  }
}
