/// Progreso de un integrante en una playlist (members/{id}/progress/{playlistId}).
class PlaylistProgress {
  const new({
    required this.playlistId,
    this.completedVideoIds = const {},
    this.positionsSeconds = const {},
    this.lastVideoId,
    this.updatedAt,
  });

  final String playlistId;
  final Set<String> completedVideoIds;

  /// Avance guardado de los videos a medias (§8.6), en segundos.
  final Map<String, int> positionsSeconds;
  final String? lastVideoId;
  final DateTime? updatedAt;

  bool isCompleted(String videoId) => completedVideoIds.contains(videoId);

  Duration? positionOf(String videoId) {
    final seconds = positionsSeconds[videoId];
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// Fracción completada (0–1) contando solo los videos que siguen activos,
  /// así nunca pasa del 100 % aunque se borre un video.
  double fractionOf(Iterable<String> activeVideoIds) {
    final active = activeVideoIds.toSet();
    if (active.isEmpty) return 0;
    return completedVideoIds.intersection(active).length / active.length;
  }
}
