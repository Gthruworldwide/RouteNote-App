import '../models/place.dart';
import 'hive_database.dart';

/// Local persistence for [Place] records. All reads/writes go through Hive,
/// making the app fully offline-first.
class PlaceLocalDataSource {
  PlaceLocalDataSource(this._database);

  final HiveDatabase _database;

  /// Returns all places, newest first.
  Future<List<Place>> getAll() async {
    final List<Place> places = _database.placesBox.values
        .whereType<Map>()
        .map((Map raw) => Place.fromMap(Map<String, dynamic>.from(raw)))
        .toList();
    places.sort((Place a, Place b) => b.timestamp.compareTo(a.timestamp));
    return places;
  }

  Future<Place?> getById(String id) async {
    final Object? raw = _database.placesBox.get(id);
    if (raw is Map) return Place.fromMap(Map<String, dynamic>.from(raw));
    return null;
  }

  /// Inserts or updates a place (keyed by its id).
  Future<void> put(Place place) async {
    await _database.placesBox.put(place.id, place.toMap());
  }

  Future<void> delete(String id) async {
    await _database.placesBox.delete(id);
  }

  /// Atomically replaces the whole local store (used by restore-from-Drive).
  Future<void> replaceAll(Iterable<Place> places) async {
    final Map<String, Map<String, dynamic>> entries =
        <String, Map<String, dynamic>>{
          for (final Place place in places) place.id: place.toMap(),
        };
    await _database.placesBox.clear();
    await _database.placesBox.putAll(entries);
  }
}
