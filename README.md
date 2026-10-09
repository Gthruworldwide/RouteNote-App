# RouteNote

**Save your favourite places offline. Sync them to your private Google Drive.**

RouteNote is an offline-first, zero-backend Flutter app for Android and iOS. It
saves GPS locations locally on the device (Hive), syncs a single JSON backup to
your *private* Google Drive app-data folder (`drive.appdata` scope — no other
Drive files are ever touched), and delegates turn-by-turn navigation to Google
Maps or Waze via deep links.

No Firebase. No custom backend. Your data is yours.

## Features

- 📍 Save your current GPS location with a name and notes
- 💾 Fully offline-first — all data lives in a local Hive database
- ☁️ One-tap backup/sync to your **private** Google Drive app-data folder
  - "Device wins": your device data always overwrites the Drive backup
  - On a fresh device (empty database), the Drive backup is restored automatically
- 🔁 Auto-sync on app open when a Google session is restored, plus a 24h
  background backup task aligned to midnight (`workmanager`)
- 🧭 Navigation delegated to Google Maps / Waze via deep links (`url_launcher`)
- 🌐 Arabic / English UI (`flutter_localizations` + ARB files), no hardcoded strings
- 🌗 Light & dark themes

## Architecture

```
UI (Home / Add / Detail / Settings)          ← 4 screens, plain Navigator
      │
Riverpod 3 (AsyncNotifier / Notifier)        ← state management
      │
Repositories (PlaceRepository, SyncRepository)
      │                        │
PlaceLocalDataSource       DriveService
(Hive boxes)                (googleapis Drive v3 + _AuthenticatedClient)
      │                        │
Local JSON backup        Google OAuth 2.0 (google_sign_in v7)
```

| Concern | Choice |
| --- | --- |
| State management | Riverpod 3.4.3 (`Notifier` / `AsyncNotifier`) |
| Local storage | `hive_ce` + `hive_ce_flutter` |
| Google sign-in | `google_sign_in` 7.x new API (`authenticate(scopeHint:)`) |
| Drive API | `googleapis` v3 with a custom `http.BaseClient` injecting the Bearer header |
| Background sync | `workmanager` 24h periodic task (`ExistingPeriodicWorkPolicy.update`) |
| Navigation | `url_launcher` intents only — no in-app turn-by-turn |
| Routing | Plain `Navigator` (no go_router) |

### Backup format

The Drive backup is a single JSON file (`routenote_backup.json`) in the
app-specific Drive folder:

```json
{
  "last_synced": "2026-10-09T12:00:00Z",
  "places": [
    {
      "id": "uuid-v4",
      "name": "Cairo Tower",
      "notes": "Near the Nile",
      "latitude": 30.0444,
      "longitude": 31.2357,
      "timestamp": "2026-10-09T11:00:00Z"
    }
  ]
}
```

## Getting started

### Prerequisites

- Flutter 3.44+ (`stable`)
- Android Studio (Android) and/or Xcode (iOS)
- A Google Cloud project for the Drive backup

### 1. Install dependencies

```sh
flutter pub get
flutter gen-l10n        # runs automatically on build; explicit here is fine
```

### 2. Google Cloud / OAuth setup (required for Drive sync)

The app never ships with real OAuth client IDs. They are injected at build time
via `--dart-define`. To create yours:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/) and create
   (or select) a project.
2. **Enable the Google Drive API**:
   *APIs & Services → Library → search "Google Drive API" → Enable.*
3. Create OAuth client IDs under **APIs & Services → Credentials → Create
   Credentials → OAuth client ID**:
   - **Android** → create an *Android* OAuth client (SHA-1 from your debug/release
     keystore) and note its **Client ID** — this becomes `GOOGLE_SERVER_CLIENT_ID`.
     `google_sign_in` requires the *Web application* client ID as
     `serverClientId` on Android, so:
     - create a **Web application** type ID for the server client,
     - and use the **Android** type client for the Play Services lookup.
   - **iOS** → create an *iOS* OAuth client and copy the app's **Bundle ID**
     (it must match `ios/Runner.xcodeproj`). This ID becomes
     `GOOGLE_IOS_CLIENT_ID` and is also added to the iOS app's `Info.plist` URL
     schemes (`com.googleusercontent.apps.<ios-client-id>`).

   > The app requests only the `https://www.googleapis.com/auth/drive.appdata`
   > scope — Google only grants access to the app's own hidden data folder, never
   > the user's documents, photos, or Drive files.

#### OAuth consent screen (one-time, required before sign-in works)

1. Open **APIs & Services → OAuth consent screen** in your project.
2. User type: **External** (an "Internal" app only works inside a Google
   Workspace you own). Fill in the app name and support email.
3. **Scopes**: add exactly one — `https://www.googleapis.com/auth/drive.appdata`
   ("See and manage your app's data folder in Google Drive"). If it is not in
   the picker, use **Add manually** and paste the scope URI.
4. **Test users**: add your own Google account(s). While the app is in
   **Testing** status, only these accounts can authorize — publishing is not
   required for personal/MVP use.
5. **Publish** the app only when ready to let anyone sign in. Note that
   `drive.appdata` is a sensitive scope: for external users Google may ask for
   an app verification review. As the project owner / test user you can
   authorize regardless; the app still works for you without waiting on review.
6. Android additionally needs an **Android OAuth client** whose SHA-1 matches
   your signing keystore (debug + release): *Credentials → Create credentials →
   OAuth client ID → Android*, with the SHA-1 from `keytool` / `signingReport`.
   This lets Play Services recognize your app; the actual OAuth client that
   `google_sign_in` uses at runtime is the **Web application** ID, passed via
   `GOOGLE_SERVER_CLIENT_ID`.

### 3. Run

```sh
# Android
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com

# iOS (same flags; iOS client ID is what matters here)
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com
```

Release builds use the same `--dart-define` flags:

```sh
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=GOOGLE_IOS_CLIENT_ID=...
flutter build ios --release --dart-define=GOOGLE_SERVER_CLIENT_ID=... --dart-define=GOOGLE_IOS_CLIENT_ID=...
```

> Without these defines the app builds and runs fully offline — sign-in is simply
> unavailable until real client IDs are supplied.

### 4. Quality gates

```sh
flutter analyze     # no issues
flutter test        # widget smoke tests (Hive-backed)
```

## Platform configuration (already in place)

- **Android** — `AndroidManifest.xml` declares `INTERNET`, coarse/fine location,
  `RECEIVE_BOOT_COMPLETED` (re-registers the background task after reboot), and a
  `<queries>` block for the `geo`, `google.navigation`, and `https` intents used
  by deep links.
- **iOS** — `Info.plist` includes `NSLocationWhenInUseUsageDescription` and
  `LSApplicationQueriesSchemes` (`comgooglemaps`, `googlemaps`, `waze`).

## Background sync

- On every app launch, once a Google session is restored, a **device-wins** sync
  runs (`SyncRepository.syncNow`):
  - local data is non-empty → local data overwrites the Drive backup;
  - local data is empty and a backup exists → the backup is restored into the
    device (used when installing on a new phone).
- A `workmanager` periodic task backs up every 24h, first scheduled at the next
  midnight (`BackgroundSyncScheduler`). It runs in a separate background isolate
  and re-initialises Hive itself — see `backgroundSyncDispatcher` in
  `lib/src/services/background_sync_scheduler.dart`.

## Project layout

```
lib/
  app.dart                     # MaterialApp (l10n, theme, locale)
  main.dart                    # bootstrap: Hive init + ProviderScope
  l10n/                        # app_en.arb, app_ar.arb (+ generated/)
  src/
    core/config/app_config.dart    # --dart-define OAuth IDs, scopes, names
    core/theme/app_theme.dart
    core/utils/date_formats.dart
    data/
      models/                      # Place, BackupData (JSON shape)
      local/                       # HiveDatabase, PlaceLocalDataSource, SettingsRepository
      remote/                      # auth_service, google_auth_service, drive_service
      repositories/                # PlaceRepository, SyncRepository
    services/                      # location, navigation, background sync
    providers/app_providers.dart   # all Riverpod providers & notifiers
    features/                      # home, add_place, place_detail, settings
test/widget_test.dart
```

## Notes

- The device copy is always the source of truth; the Drive file is a backup.
- Restoration is automatic only when the device database is empty and a backup
  exists. A manual **Restore from Google Drive** action is also available in
  Settings (with confirmation).
- No analytics, no tracking, no third-party network calls besides Google OAuth /
  Drive and the maps deep links you tap yourself.