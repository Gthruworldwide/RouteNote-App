import 'place.dart';

/// The serialised payload that is uploaded to Google Drive.
///
/// ```json
/// {
///   "last_synced": "2026-10-09T00:00:00Z",
///   "places": [ ... ]
/// }
/// ```
class BackupData {
  const BackupData({required this.places, this.lastSynced});

  final DateTime? lastSynced;
  final List<Place> places;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'last_synced': lastSynced?.toUtc().toIso8601String(),
      'places': places.map((Place place) => place.toJson()).toList(),
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final Object? rawPlaces = json['places'];
    final List<Place> places = <Place>[];
    if (rawPlaces is List) {
      for (final Object? item in rawPlaces) {
        if (item is Map) {
          places.add(Place.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return BackupData(
      places: places,
      lastSynced: _parseDate(json['last_synced']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return null;
  }
}
