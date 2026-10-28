import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/core/data/firestore_mappers.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';

/// Las consultas coinciden con los índices de `firestore.indexes.json`.
/// En la User App siempre filtran `is_active == true`: las reglas no son
/// filtros y una consulta sin ese filtro sería rechazada para inactivos.
class FirestoreCatalogRepository implements CatalogRepository {
  new(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Category>> watchCategories({bool includeInactive = false}) {
    Query<Json> q = _db.collection('categories');
    if (!includeInactive) q = q.where('is_active', isEqualTo: true);
    return q
        .orderBy('order')
        .snapshots()
        .map(
          (s) => [
            for (final d in s.docs) categoryFromFirestore(d.id, d.data()),
          ],
        );
  }

  @override
  Stream<List<Playlist>> watchPlaylists(
    String categoryId, {
    bool includeInactive = false,
  }) {
    var q = _db
        .collection('playlists')
        .where('category_id', isEqualTo: categoryId);
    if (!includeInactive) q = q.where('is_active', isEqualTo: true);
    return q
        .orderBy('order')
        .snapshots()
        .map(
          (s) => [
            for (final d in s.docs) playlistFromFirestore(d.id, d.data()),
          ],
        );
  }

  @override
  Stream<List<Video>> watchVideos(
    String playlistId, {
    bool includeInactive = false,
  }) {
    var q = _db
        .collection('videos')
        .where('playlist_id', isEqualTo: playlistId);
    if (!includeInactive) q = q.where('is_active', isEqualTo: true);
    return q
        .orderBy('day_number')
        .orderBy('order')
        .snapshots()
        .map(
          (s) => [for (final d in s.docs) videoFromFirestore(d.id, d.data())],
        );
  }
}
