/// Compile-time configuration for RouteNote.
///
/// None of these values should ever be hardcoded secrets. OAuth client ids are
/// public identifiers; they are injected with `--dart-define` at build time:
///
/// ```sh
/// flutter run \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com
/// ```
class AppConfig {
  const AppConfig._();

  /// Web / server OAuth client id. Required on Android for `google_sign_in`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// iOS OAuth client id. Required on iOS.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Drive scope that grants access to the hidden, app-specific
  /// `appDataFolder` only. The user's other Drive files are never visible.
  static const String driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  static const List<String> driveScopes = <String>[driveAppDataScope];

  /// Name of the single JSON backup file stored in the app data folder.
  static const String backupFileName = 'routenote_backup.json';

  static const String backupMimeType = 'application/json';

  /// Hive box names.
  static const String placesBoxName = 'places';
  static const String settingsBoxName = 'settings';

  /// How often the periodic background backup runs.
  static const Duration backgroundSyncFrequency = Duration(hours: 24);

  /// Unique name used by the background task scheduler.
  static const String backgroundSyncUniqueName = 'routenote.periodicSync';
}
