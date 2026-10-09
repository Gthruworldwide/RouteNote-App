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

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
