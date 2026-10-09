/// A saved location. This is the core domain entity of RouteNote.
///
/// The JSON shape matches the documented backup format:
/// ```json
/// {
///   "id": "uuid-v4-string",
///   "name": "Target Name",
///   "notes": "Optional details",
///   "latitude": 30.12345,
///   "longitude": 31.12345,
///   "timestamp": "2026-10-09T15:30:00Z"
/// }
/// ```
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.notes,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String id;
  final String name;
  final String notes;
  final double latitude;
  final double longitude;

  /// Creation time, stored in UTC.
  final DateTime timestamp;

  Place copyWith({
    String? id,
    String? name,
    String? notes,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// A compact single-line label used to preview coordinates.
  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory Place.fromMap(Map<String, dynamic> map) {
    return Place(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      timestamp: _toDateTime(map['timestamp']),
    );
  }

  factory Place.fromJson(Map<String, dynamic> json) => Place.fromMap(json);

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime _toDateTime(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return DateTime.now().toUtc();
  }

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.id == id &&
      other.name == name &&
      other.notes == notes &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timestamp == timestamp;

  @override
  int get hashCode =>
      Object.hash(id, name, notes, latitude, longitude, timestamp);

  @override
  String toString() => 'Place($id, $name, $latitude, $longitude)';
}
