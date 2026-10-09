import '../local/place_local_data_source.dart';
import '../models/place.dart';

/// Application-level persistence operations for places.
class PlaceRepository {
  PlaceRepository(this._local);

  final PlaceLocalDataSource _local;

  Future<List<Place>> getAll() => _local.getAll();

  Future<Place?> getById(String id) => _local.getById(id);

  Future<void> save(Place place) => _local.put(place);

  Future<void> delete(String id) => _local.delete(id);

  Future<void> replaceAll(Iterable<Place> places) => _local.replaceAll(places);
}
