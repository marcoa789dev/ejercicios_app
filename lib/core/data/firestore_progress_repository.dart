import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/core/data/firestore_errors.dart';
import 'package:ejercicios_app/core/data/firestore_mappers.dart';
import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';

/// Todas las escrituras usan `merge`: funcionan sin conexión (se encolan) y
/// no pisan los demás campos del documento de progreso.
class FirestoreProgressRepository implements ProgressRepository {
  new(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Json> _progress(String memberId) =>
      _db.collection('members').doc(memberId).collection('progress');

  @override
  Stream<Map<String, PlaylistProgress>> watchProgress(String memberId) =>
      _progress(memberId).snapshots().map(
        (s) => {
          for (final d in s.docs) d.id: progressFromFirestore(d.id, d.data()),
        },
      );

  @override
  Future<Result<void>> setCompleted({
    required String memberId,
    required String playlistId,
    required String videoId,
    required bool completed,
  }) => guardFirestore(
    () => _progress(memberId).doc(playlistId).set({
      'playlist_id': playlistId,
      'completed_video_ids': completed
          ? FieldValue.arrayUnion([videoId])
          : FieldValue.arrayRemove([videoId]),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)),
  );

  @override
  Future<Result<void>> savePosition({
    required String memberId,
    required String playlistId,
    required String videoId,
    required Duration position,
  }) => guardFirestore(
    () => _progress(memberId).doc(playlistId).set({
      'playlist_id': playlistId,
      'positions': {videoId: position.inSeconds},
      'last_video_id': videoId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)),
  );

  @override
  Future<Result<void>> clearPosition({
    required String memberId,
    required String playlistId,
    required String videoId,
  }) => guardFirestore(
    () => _progress(memberId).doc(playlistId).set({
      'playlist_id': playlistId,
      'positions': {videoId: FieldValue.delete()},
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)),
  );
}
