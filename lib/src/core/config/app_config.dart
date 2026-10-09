/// Compile-time configuration for RouteNote.
///
/// None of these values are secrets. OAuth *client* ids are public identifiers
/// (the client *secret* is never used by the app). They default to the RouteNote
/// Google Cloud project so the app works however it is launched (IDE, adb, or
/// the run script), and can be overridden at build time:
///
/// ```sh
/// flutter run \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com
/// ```
class AppConfig {
  const AppConfig._();

  /// Web / server OAuth client id. Required on Android for `google_sign_in`.
  ///
  /// Defaults to the RouteNote Web client; override with
  /// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '679774190551-ojvh4k0r769c77osa7n0v3a3itlvsfr4.apps.googleusercontent.com',
  );

  /// iOS OAuth client id. Required on iOS. Public identifier; see
  /// [googleServerClientId]. Override with `--dart-define=GOOGLE_IOS_CLIENT_ID=...`.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '679774190551-79f3eefd6ncu34appi5rie8lo2use8i9.apps.googleusercontent.com',
  );

  /// Human-readable version shown in Settings → About.
  ///
  /// Keep in sync with the `version` field in `pubspec.yaml`.
  static const String appVersion = '1.0.1';

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
