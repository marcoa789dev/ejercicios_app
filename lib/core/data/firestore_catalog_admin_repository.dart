import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/core/data/firestore_errors.dart';
import 'package:ejercicios_app/core/data/firestore_mappers.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';

/// Escrituras del catálogo desde la Admin App (§6.3, §9).
///
/// Los agregados de la playlist se recalculan con una consulta justo después
/// de cada escritura de videos: el SDK de cliente no permite consultas
/// dentro de una transacción, y con un solo admin no hay escrituras
/// concurrentes que los descuadren.
class FirestoreCatalogAdminRepository implements CatalogAdminRepository {
  new(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> get _categories => _db.collection('categories');
  CollectionReference<Json> get _playlists => _db.collection('playlists');
  CollectionReference<Json> get _videos => _db.collection('videos');

  Query<Json> _videosOf(String playlistId) =>
      _videos.where('playlist_id', isEqualTo: playlistId);

  static Json _stamps({required bool created}) => {
    'updated_at': FieldValue.serverTimestamp(),
    if (created) 'created_at': FieldValue.serverTimestamp(),
  };

  static Future<int> _nextOrder(
    Query<Json> query, {
    bool Function(Json data)? where,
  }) async {
    var max = 0;
    for (final d in (await query.get()).docs) {
      if (where != null && !where(d.data())) continue;
      final order = d.data()['order'];
      if (order is num && order > max) max = order.toInt();
    }
    return max + 1;
  }

  /// Reescribe `order` (1, 2, 3…) solo de los que cambiaron de posición.
  Future<void> _reorder(
    CollectionReference<Json> col,
    List<({String id, int order})> ordered,
  ) async {
    final batch = _db.batch();
    var changed = false;
    for (final (i, item) in ordered.indexed) {
      if (item.order == i + 1) continue;
      batch.update(col.doc(item.id), {
        'order': i + 1,
        'updated_at': FieldValue.serverTimestamp(),
      });
      changed = true;
    }
    if (changed) await batch.commit();
  }

  /// Totales de la playlist a partir de sus videos activos.
  Future<void> _recalculate(String playlistId) async {
    var count = 0;
    var seconds = 0;
    final days = <int>{};
    for (final d in (await _videosOf(playlistId).get()).docs) {
      final v = videoFromFirestore(d.id, d.data());
      if (!v.isActive) continue;
      count++;
      seconds += v.durationSeconds;
      days.add(v.dayNumber);
    }
    await _playlists.doc(playlistId).update({
      'total_videos': count,
      'total_duration_seconds': seconds,
      'days_count': days.length,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Categorías ----------

  @override
  Future<Result<String>> saveCategory(Category category) =>
      guardFirestore(() async {
        final created = category.id.isEmpty;
        final ref = created ? _categories.doc() : _categories.doc(category.id);
        final data = categoryToFirestore(category);
        if (created) data['order'] = await _nextOrder(_categories);
        await ref.set({
          ...data,
          ..._stamps(created: created),
        }, SetOptions(merge: true));
        return ref.id;
      });

  @override
  Future<Result<void>> reorderCategories(List<Category> ordered) =>
      guardFirestore(
        () => _reorder(_categories, [
          for (final c in ordered) (id: c.id, order: c.order),
        ]),
      );

  @override
  Future<Result<void>> setCategoryActive(String id, {required bool active}) =>
      guardFirestore(
        () => _categories.doc(id).update({
          'is_active': active,
          ..._stamps(created: false),
        }),
      );

  @override
  Future<Result<void>> deleteCategory(String id) => guardFirestore(() async {
    final playlists = await _playlists
        .where('category_id', isEqualTo: id)
        .limit(1)
        .get();
    if (playlists.docs.isNotEmpty) {
      throw const FailureException(NotEmptyFailure());
    }
    await _categories.doc(id).delete();
  });

  // ---------- Playlists ----------

  @override
  Future<Result<String>> savePlaylist(Playlist playlist) =>
      guardFirestore(() async {
        final created = playlist.id.isEmpty;
        final ref = created ? _playlists.doc() : _playlists.doc(playlist.id);
        final data = playlistToFirestore(playlist);
        if (created) {
          data['order'] = await _nextOrder(
            _playlists.where('category_id', isEqualTo: playlist.categoryId),
          );
          data.addAll({
            'total_videos': 0,
            'total_duration_seconds': 0,
            'days_count': 0,
          });
        }
        await ref.set({
          ...data,
          ..._stamps(created: created),
        }, SetOptions(merge: true));
        return ref.id;
      });

  @override
  Future<Result<void>> reorderPlaylists(List<Playlist> ordered) =>
      guardFirestore(
        () => _reorder(_playlists, [
          for (final p in ordered) (id: p.id, order: p.order),
        ]),
      );

  @override
  Future<Result<void>> setPlaylistActive(String id, {required bool active}) =>
      guardFirestore(
        () => _playlists.doc(id).update({
          'is_active': active,
          ..._stamps(created: false),
        }),
      );

  @override
  Future<Result<String>> duplicatePlaylist(
    String id, {
    required String newTitle,
  }) => guardFirestore(() async {
    final source = await _playlists.doc(id).get();
    final data = source.data();
    if (data == null) throw const FailureException(NotFoundFailure());

    final siblings = _playlists.where(
      'category_id',
      isEqualTo: data['category_id'],
    );
    var lastWeek = 0;
    for (final d in (await siblings.get()).docs) {
      final w = d.data()['week_number'];
      if (w is num && w > lastWeek) lastWeek = w.toInt();
    }

    final copy = _playlists.doc();
    final batch = _db.batch()
      ..set(copy, {
        ...data,
        'title': newTitle,
        'week_number': lastWeek + 1,
        'order': await _nextOrder(siblings),
        'is_active': false,
        ..._stamps(created: true),
      });
    for (final v in (await _videosOf(id).get()).docs) {
      batch.set(_videos.doc(), {
        ...v.data(),
        'playlist_id': copy.id,
        ..._stamps(created: true),
      });
    }
    await batch.commit();
    return copy.id;
  });

  @override
  Future<Result<void>> deletePlaylist(String id) => guardFirestore(() async {
    final batch = _db.batch();
    for (final v in (await _videosOf(id).get()).docs) {
      batch.delete(v.reference);
    }
    batch.delete(_playlists.doc(id));
    await batch.commit();
  });

  // ---------- Videos ----------

  @override
  Future<Result<String>> saveVideo(Video video) => guardFirestore(() async {
    final created = video.id.isEmpty;
    final ref = created ? _videos.doc() : _videos.doc(video.id);
    final data = videoToFirestore(video);

    // Nuevo, o movido a otro día: va al final de ese día
    var needsOrder = created;
    if (!created) {
      final before = (await ref.get()).data();
      needsOrder = before?['day_number'] != video.dayNumber;
    }
    if (needsOrder) {
      data['order'] = await _nextOrder(
        _videosOf(video.playlistId),
        where: (d) => d['day_number'] == video.dayNumber,
      );
    }

    await ref.set({
      ...data,
      ..._stamps(created: created),
    }, SetOptions(merge: true));
    await _recalculate(video.playlistId);
    return ref.id;
  });

  @override
  Future<Result<void>> arrangeVideos(
    String playlistId,
    List<VideoSlot> slots,
  ) => guardFirestore(() async {
    if (slots.isEmpty) return;
    final batch = _db.batch();
    for (final s in slots) {
      batch.update(_videos.doc(s.id), {
        'day_number': s.dayNumber,
        'order': s.order,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _recalculate(playlistId);
  });

  @override
  Future<Result<void>> setVideoActive(Video video, {required bool active}) =>
      guardFirestore(() async {
        await _videos.doc(video.id).update({
          'is_active': active,
          ..._stamps(created: false),
        });
        await _recalculate(video.playlistId);
      });

  @override
  Future<Result<void>> deleteVideo(Video video) => guardFirestore(() async {
    await _videos.doc(video.id).delete();
    await _recalculate(video.playlistId);
  });
}
