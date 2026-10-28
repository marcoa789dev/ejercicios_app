import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/result.dart';

/// Lectura del catálogo (User App y Admin App).
abstract interface class CatalogRepository {
  Stream<List<Category>> watchCategories({bool includeInactive = false});

  Stream<List<Playlist>> watchPlaylists(
    String categoryId, {
    bool includeInactive = false,
  });

  /// Ordenados por día y luego por orden dentro del día.
  Stream<List<Video>> watchVideos(
    String playlistId, {
    bool includeInactive = false,
  });
}

/// Progreso y avance de los videos de un integrante (§6.3, §8.6).
abstract interface class ProgressRepository {
  /// Progreso de todas las playlists del integrante, por id de playlist.
  Stream<Map<String, PlaylistProgress>> watchProgress(String memberId);

  Future<Result<void>> setCompleted({
    required String memberId,
    required String playlistId,
    required String videoId,
    required bool completed,
  });

  /// Guarda el segundo donde se quedó y lo marca como último video visto.
  Future<Result<void>> savePosition({
    required String memberId,
    required String playlistId,
    required String videoId,
    required Duration position,
  });

  /// Borra el avance (al terminar el video o con "Empezar de nuevo").
  Future<Result<void>> clearPosition({
    required String memberId,
    required String playlistId,
    required String videoId,
  });
}
