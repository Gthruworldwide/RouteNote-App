import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/local/hive_database.dart';
import '../data/local/place_local_data_source.dart';
import '../data/local/settings_repository.dart';
import '../data/models/place.dart';
import '../data/remote/auth_service.dart';
import '../data/remote/drive_service.dart';
import '../data/remote/google_auth_service.dart';
import '../data/repositories/place_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../services/background_sync_scheduler.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';

// ---------------------------------------------------------------------------
// Storage & repositories
// ---------------------------------------------------------------------------

/// Opened in `main()` and overridden there; never used before the app runs.
final Provider<HiveDatabase> hiveDatabaseProvider = Provider<HiveDatabase>((
  Ref ref,
) {
  throw StateError('hiveDatabaseProvider must be overridden in main()');
});

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) {
      return SettingsRepository(ref.watch(hiveDatabaseProvider).settingsBox);
    });

final Provider<PlaceLocalDataSource> placeLocalDataSourceProvider =
    Provider<PlaceLocalDataSource>((Ref ref) {
      return PlaceLocalDataSource(ref.watch(hiveDatabaseProvider));
    });

final Provider<PlaceRepository> placeRepositoryProvider =
    Provider<PlaceRepository>((Ref ref) {
      return PlaceRepository(ref.watch(placeLocalDataSourceProvider));
    });

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>((Ref ref) => const LocationService());

final Provider<NavigationService> navigationServiceProvider =
    Provider<NavigationService>((Ref ref) => const NavigationService());

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => GoogleAuthService(),
);

final Provider<DriveService> driveServiceProvider = Provider<DriveService>((
  Ref ref,
) {
  return GoogleDriveService(ref.watch(authServiceProvider));
});

final Provider<SyncRepository> syncRepositoryProvider =
    Provider<SyncRepository>((Ref ref) {
      return SyncRepository(
        placeRepository: ref.watch(placeRepositoryProvider),
        driveService: ref.watch(driveServiceProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        authService: ref.watch(authServiceProvider),
      );
    });

final Provider<BackgroundSyncScheduler> backgroundSyncSchedulerProvider =
    Provider<BackgroundSyncScheduler>(
      (Ref ref) => const BackgroundSyncScheduler(),
    );

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// The list of saved places.
final AsyncNotifierProvider<PlacesNotifier, List<Place>> placesProvider =
    AsyncNotifierProvider<PlacesNotifier, List<Place>>(PlacesNotifier.new);

/// Authentication + account state.
final AsyncNotifierProvider<AuthNotifier, AuthUser?> authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);

/// Live location availability (GPS on/off + permission) for status indicators.
final AsyncNotifierProvider<LocationStatusNotifier, LocationStatus>
locationStatusProvider =
    AsyncNotifierProvider<LocationStatusNotifier, LocationStatus>(
      LocationStatusNotifier.new,
    );

/// Backup / sync status.
final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

/// Selected locale (null = follow the system language).
final NotifierProvider<LocaleController, Locale?> localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

/// App theme mode, persisted.
final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

// ---------------------------------------------------------------------------
// Notifiers
// ---------------------------------------------------------------------------

class PlacesNotifier extends AsyncNotifier<List<Place>> {
  @override
  Future<List<Place>> build() => ref.watch(placeRepositoryProvider).getAll();

  Future<void> save(Place place) async {
    await ref.read(placeRepositoryProvider).save(place);
    await _refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(placeRepositoryProvider).delete(id);
    await _refresh();
  }

  /// Re-fetches after a Drive restore triggered elsewhere.
  Future<void> reload() async {
    state = const AsyncValue<List<Place>>.loading();
    state = await AsyncValue.guard<List<Place>>(
      () => ref.read(placeRepositoryProvider).getAll(),
    );
  }

  Future<void> _refresh() async {
    final List<Place> places = await ref.read(placeRepositoryProvider).getAll();
    state = AsyncValue<List<Place>>.data(places);
  }
}

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final AuthService auth = ref.watch(authServiceProvider);
    try {
      await auth.initialize();
      return await auth.restoreSession();
    } catch (_) {
      return null;
    }
  }

  Future<void> signIn() async {
    state = const AsyncValue<AuthUser?>.loading();
    state = await AsyncValue.guard<AuthUser?>(
      () => ref.read(authServiceProvider).signIn(),
    );
    final Object? error = state.error;
    if (error != null) {
      debugPrint('RouteNote sign-in error: $error');
    }
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    state = AsyncValue<AuthUser?>.data(null);
  }
}

enum SyncStatus { idle, syncing, success, error, skipped }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSynced,
    this.outcome,
    this.error,
  });

  final SyncStatus status;
  final DateTime? lastSynced;
  final SyncOutcome? outcome;
  final String? error;

  bool get isSyncing => status == SyncStatus.syncing;

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSynced,
    SyncOutcome? outcome,
    bool clearError = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSynced: lastSynced ?? this.lastSynced,
      outcome: outcome ?? this.outcome,
      error: clearError ? null : error,
    );
  }
}

class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() {
    return SyncState(
      lastSynced: ref.watch(settingsRepositoryProvider).lastSynced,
    );
  }

  /// Performs the "device wins" sync, keeping the UI state in sync.
  Future<void> syncNow() async {
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      final SyncOutcome outcome = await ref
          .read(syncRepositoryProvider)
          .syncNow();
      state = SyncState(
        status: outcome == SyncOutcome.skippedNotSignedIn
            ? SyncStatus.skipped
            : SyncStatus.success,
        outcome: outcome,
        lastSynced: ref.read(settingsRepositoryProvider).lastSynced,
      );
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        error: e.toString(),
        lastSynced: ref.read(settingsRepositoryProvider).lastSynced,
      );
    }
    // The restored list (if any) should refresh the UI.
    await ref.read(placesProvider.notifier).reload();
  }

  /// Silent sync for app lifecycle events (e.g. returning to the foreground).
  ///
  /// Skips when a sync is already running, and throttles to at most one sync
  /// per [silentSyncMinInterval] so quick app switches stay cheap and do not
  /// hammer the Drive API.
  Future<void> syncSilently() async {
    if (state.isSyncing) return;
    final DateTime? lastSynced = state.lastSynced;
    if (lastSynced != null &&
        DateTime.now().toUtc().difference(lastSynced) < silentSyncMinInterval) {
      return;
    }
    await syncNow();
  }

  static const Duration silentSyncMinInterval = Duration(minutes: 1);

  /// Downloads the Drive backup and replaces local data.
  Future<void> restoreFromDrive() async {
    state = state.copyWith(status: SyncStatus.syncing, clearError: true);
    try {
      await ref.read(syncRepositoryProvider).restoreFromDrive();
      state = SyncState(
        status: SyncStatus.success,
        outcome: SyncOutcome.restored,
        lastSynced: ref.read(settingsRepositoryProvider).lastSynced,
      );
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        error: e.toString(),
        lastSynced: ref.read(settingsRepositoryProvider).lastSynced,
      );
    }
    await ref.read(placesProvider.notifier).reload();
  }
}

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final String? code = ref.watch(settingsRepositoryProvider).localeCode;
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    await ref
        .read(settingsRepositoryProvider)
        .setLocaleCode(locale?.languageCode);
    state = locale;
  }
}

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final int? index = ref.watch(settingsRepositoryProvider).themeModeIndex;
    if (index == null || index < 0 || index >= ThemeMode.values.length) {
      return ThemeMode.system;
    }
    return ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(settingsRepositoryProvider).setThemeModeIndex(mode.index);
    state = mode;
  }
}

/// Exposes the device's location availability and drives the user to the right
/// OS surface when location access is missing.
class LocationStatusNotifier extends AsyncNotifier<LocationStatus> {
  @override
  Future<LocationStatus> build() => _read();

  Future<LocationStatus> _read() async {
    final LocationService service = ref.read(locationServiceProvider);
    final bool serviceEnabled = await service.isServiceEnabled();
    final LocationPermission permission = await service.checkPermission();
    return LocationStatus(
      serviceEnabled: serviceEnabled,
      permission: permission,
    );
  }

  /// Re-reads the status without flashing a loading state (used on resume).
  Future<void> refresh() async {
    try {
      state = AsyncValue<LocationStatus>.data(await _read());
    } catch (error, stackTrace) {
      state = AsyncValue<LocationStatus>.error(error, stackTrace);
    }
  }

  /// Sends the user to the right place to grant location access:
  /// - GPS switched off → the system location settings screen.
  /// - Permission permanently denied → this app's settings screen.
  /// - Otherwise → the runtime permission dialog.
  Future<void> requestAccessFromUser() async {
    final LocationService service = ref.read(locationServiceProvider);
    final LocationStatus? status = state.value;
    if (status != null) {
      if (!status.serviceEnabled) {
        await service.openLocationSettings();
      } else if (!status.permissionGranted) {
        if (status.permission == LocationPermission.deniedForever) {
          await service.openAppSettings();
        } else {
          await service.requestPermission();
        }
      }
    }
    await refresh();
  }
}
