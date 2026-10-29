import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/progress.dart';

/// Qué video toca en una playlist (§8.6 "Continuar").
class NextUp {
  const new({required this.index, required this.resumeAt});

  /// Posición en la lista de videos activos.
  final int index;

  /// Avance guardado si el video quedó a medias.
  final Duration? resumeAt;

  bool get isResume => resumeAt != null;
}

/// 1. El último video visto, si quedó a medias y no está completado.
/// 2. Si no, el primer video sin completar.
/// 3. `null` si ya completó todos.
///
/// [videos] son los activos, en orden (día y luego orden).
NextUp? nextUp(List<Video> videos, PlaylistProgress? progress) {
  if (videos.isEmpty) return null;
  if (progress == null) return const NextUp(index: 0, resumeAt: null);

  final last = progress.lastVideoId;
  if (last != null && !progress.isCompleted(last)) {
    final i = videos.indexWhere((v) => v.id == last);
    final at = progress.positionOf(last);
    if (i != -1 && at != null) return NextUp(index: i, resumeAt: at);
  }
  final i = videos.indexWhere((v) => !progress.isCompleted(v.id));
  if (i == -1) return null;
  return NextUp(index: i, resumeAt: progress.positionOf(videos[i].id));
}

/// Fracción para las tarjetas del Home sin cargar los videos: los
/// completados se topan en el total, así nunca pasa del 100 %.
double cardFraction(Playlist p, PlaylistProgress? progress) {
  if (p.totalVideos == 0 || progress == null) return 0;
  final done = progress.completedVideoIds.length;
  return (done > p.totalVideos ? p.totalVideos : done) / p.totalVideos;
}
