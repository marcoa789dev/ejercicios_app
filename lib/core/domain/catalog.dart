import 'package:ejercicios_app/core/utils/video_url_resolver.dart';

/// Nivel de una playlist. `wire` es el valor guardado en Firestore.
enum Level {
  beginner('beginner', 'Principiante'),
  intermediate('intermediate', 'Intermedio'),
  advanced('advanced', 'Avanzado');

  new(this.wire, this.label);

  final String wire;
  final String label;

  static Level fromWire(String? value) =>
      values.firstWhere((l) => l.wire == value, orElse: () => beginner);
}

/// Zona del cuerpo o meta (ej. "Rodilla").
class Category {
  const new({
    required this.id,
    required this.name,
    required this.order,
    this.description = '',
    this.icon,
    this.colorHex,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String description;
  final String? icon;
  final String? colorHex;
  final int order;
  final bool isActive;
}

/// Una semana de rutinas (ej. "Semana de la rodilla").
class Playlist {
  const new({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.order,
    this.description = '',
    this.goal = '',
    this.thumbnailUrl,
    this.level = Level.beginner,
    this.weekNumber = 1,
    this.isActive = true,
    this.totalVideos = 0,
    this.totalDurationSeconds = 0,
    this.daysCount = 0,
  });

  final String id;
  final String categoryId;
  final String title;
  final String description;
  final String goal;
  final String? thumbnailUrl;
  final Level level;
  final int weekNumber;
  final int order;
  final bool isActive;
  final int totalVideos;
  final int totalDurationSeconds;
  final int daysCount;

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);
}

/// Un video de la playlist, asignado a un día (1–7).
class Video {
  const new({
    required this.id,
    required this.playlistId,
    required this.categoryId,
    required this.title,
    required this.dayNumber,
    required this.order,
    required this.streamUrl,
    required this.durationSeconds,
    this.source = VideoSource.r2,
    this.rawUrl,
    this.instructions = '',
    this.sets,
    this.reps,
    this.thumbnailUrl,
    this.isActive = true,
  });

  final String id;
  final String playlistId;
  final String categoryId;
  final String title;
  final String instructions;
  final int? sets;
  final int? reps;
  final int dayNumber;
  final int order;
  final VideoSource source;
  final String? rawUrl;
  final String streamUrl;
  final int durationSeconds;
  final String? thumbnailUrl;
  final bool isActive;

  Duration get duration => Duration(seconds: durationSeconds);
}
