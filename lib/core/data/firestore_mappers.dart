import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/utils/video_url_resolver.dart';

/// Traducción entre documentos de Firestore (snake_case) y entidades.
/// Los campos faltantes toman valores por defecto: un documento incompleto
/// no debe tumbar la app.
typedef Json = Map<String, dynamic>;

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
int? _intOrNull(Object? v) => v is num ? v.toInt() : null;
String _str(Object? v, [String fallback = '']) => v is String ? v : fallback;
String? _strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;
bool _bool(Object? v, {bool fallback = true}) => v is bool ? v : fallback;

Category categoryFromFirestore(String id, Json d) => Category(
  id: id,
  name: _str(d['name']),
  description: _str(d['description']),
  icon: _strOrNull(d['icon']),
  colorHex: _strOrNull(d['color_hex']),
  order: _int(d['order']),
  isActive: _bool(d['is_active']),
);

Playlist playlistFromFirestore(String id, Json d) => Playlist(
  id: id,
  categoryId: _str(d['category_id']),
  title: _str(d['title']),
  description: _str(d['description']),
  goal: _str(d['goal']),
  thumbnailUrl: _strOrNull(d['thumbnail_url']),
  level: Level.fromWire(d['level'] as String?),
  weekNumber: _int(d['week_number'], 1),
  order: _int(d['order']),
  isActive: _bool(d['is_active']),
  totalVideos: _int(d['total_videos']),
  totalDurationSeconds: _int(d['total_duration_seconds']),
  daysCount: _int(d['days_count']),
);

Video videoFromFirestore(String id, Json d) => Video(
  id: id,
  playlistId: _str(d['playlist_id']),
  categoryId: _str(d['category_id']),
  title: _str(d['title']),
  instructions: _str(d['instructions']),
  sets: _intOrNull(d['sets']),
  reps: _intOrNull(d['reps']),
  dayNumber: _int(d['day_number'], 1),
  order: _int(d['order']),
  source: VideoSource.fromWire(d['video_source'] as String?),
  rawUrl: _strOrNull(d['raw_url']),
  streamUrl: _str(d['stream_url']),
  durationSeconds: _int(d['duration_seconds']),
  thumbnailUrl: _strOrNull(d['thumbnail_url']),
  isActive: _bool(d['is_active']),
);

PlaylistProgress progressFromFirestore(String playlistId, Json d) {
  final positions = <String, int>{};
  final raw = d['positions'];
  if (raw is Map) {
    for (final MapEntry(:key, :value) in raw.entries) {
      if (key is String && value is num) positions[key] = value.toInt();
    }
  }
  final completed = d['completed_video_ids'];
  final updatedAt = d['updated_at'];
  return PlaylistProgress(
    playlistId: playlistId,
    completedVideoIds: completed is List
        ? completed.whereType<String>().toSet()
        : const {},
    positionsSeconds: positions,
    lastVideoId: _strOrNull(d['last_video_id']),
    updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
  );
}
