import 'package:geolocator/geolocator.dart';

/// Result of a location request.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  const LocationSuccess({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
}

class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied({required this.permanentlyDenied});

  final bool permanentlyDenied;
}

class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

class LocationFailure extends LocationResult {
  const LocationFailure(this.message);

  final String message;
}

/// A snapshot of the device's location availability, used by UI indicators.
class LocationStatus {
  const LocationStatus({
    required this.serviceEnabled,
    required this.permission,
  });

  /// Whether the system location service (GPS) is switched on.
  final bool serviceEnabled;

  /// The current permission level the OS reports for this app.
  final LocationPermission permission;

  /// True when the app is allowed to read the device location.
  bool get permissionGranted =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  /// True when the user must act before location can be read.
  bool get needsAction => !serviceEnabled || !permissionGranted;
}

/// GPS capture built on `geolocator`.
class LocationService {
  const LocationService();

  Future<LocationResult> determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationServiceDisabled();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return LocationPermissionDenied(
        permanentlyDenied: permission == LocationPermission.deniedForever,
      );
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationSuccess(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    } catch (e) {
      return LocationFailure(e.toString());
    }
  }

  /// Whether the system location service (GPS) is currently enabled.
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Reads the current permission level without prompting the user.
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  /// Shows the OS permission dialog when possible.
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
