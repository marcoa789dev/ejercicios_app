import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';

/// Fila de la lista de videos: encabezado de día o video.
sealed class VideoRow {
  const new();
}

final class DayHeader extends VideoRow {
  const new(this.day);

  final int day;
}

final class VideoItem extends VideoRow {
  const new(this.video);

  final Video video;
}

const kDaysPerWeek = 7;

/// Encabezados "Día 1" … "Día 7", cada uno seguido de sus videos en orden.
List<VideoRow> buildRows(List<Video> videos) {
  final sorted = [...videos]
    ..sort((a, b) {
      final byDay = a.dayNumber.compareTo(b.dayNumber);
      return byDay != 0 ? byDay : a.order.compareTo(b.order);
    });
  return [
    for (var day = 1; day <= kDaysPerWeek; day++) ...[
      DayHeader(day),
      for (final v in sorted.where((v) => v.dayNumber == day)) VideoItem(v),
    ],
  ];
}

/// Mueve la fila [from] a [to] (índice después de quitarla, como en
/// `onReorderItem`). Un video toma el día del encabezado que queda arriba
/// de él, así arrastrar sirve para reordenar y para cambiar de día.
/// Devuelve las filas nuevas y solo los videos que cambiaron.
({List<VideoRow> rows, List<VideoSlot> changed}) moveRow(
  List<VideoRow> rows,
  int from,
  int to,
) {
  if (rows[from] is DayHeader) return (rows: rows, changed: const []);
  final next = [...rows];
  final moved = next.removeAt(from);
  // Nada puede quedar antes de "Día 1"
  next.insert(to < 1 ? 1 : to, moved);

  final changed = <VideoSlot>[];
  var day = 1;
  var order = 0;
  for (final (i, row) in next.indexed) {
    switch (row) {
      case DayHeader():
        day = row.day;
        order = 0;
      case VideoItem(:final video):
        order++;
        if (video.dayNumber == day && video.order == order) continue;
        changed.add((id: video.id, dayNumber: day, order: order));
        next[i] = VideoItem(placeVideo(video, day: day, order: order));
    }
  }
  return (rows: next, changed: changed);
}

/// Copia de [v] en otro día/orden.
Video placeVideo(Video v, {required int day, required int order}) => Video(
  id: v.id,
  playlistId: v.playlistId,
  categoryId: v.categoryId,
  title: v.title,
  dayNumber: day,
  order: order,
  streamUrl: v.streamUrl,
  durationSeconds: v.durationSeconds,
  source: v.source,
  rawUrl: v.rawUrl,
  instructions: v.instructions,
  sets: v.sets,
  reps: v.reps,
  thumbnailUrl: v.thumbnailUrl,
  isActive: v.isActive,
);
