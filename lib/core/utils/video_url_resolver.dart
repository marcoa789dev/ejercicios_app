/// Proveedor del video. El nombre `wire` es el que se guarda en Firestore.
enum VideoSource {
  r2('r2'),
  directMp4('direct_mp4'),
  googleDrive('google_drive');

  new(this.wire);

  final String wire;

  static VideoSource fromWire(String? value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => VideoSource.directMp4,
  );
}

class ResolvedVideoUrl {
  const new({required this.streamUrl, required this.source});

  final String streamUrl;
  final VideoSource source;
}

/// Convierte lo que pega el admin en una URL reproducible (PLAN_MAESTRO §8.2).
class VideoUrlResolver {
  const new();

  // Drive: /file/d/{ID}/view · /file/d/{ID}/preview · open?id={ID} · uc?id={ID}
  static final _drivePath = RegExp('/file/d/([a-zA-Z0-9_-]{10,})');
  static final _driveQuery = RegExp('[?&]id=([a-zA-Z0-9_-]{10,})');

  /// Lanza [FormatException] con un mensaje listo para mostrar.
  ResolvedVideoUrl resolve(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('La URL no es válida');
    }
    if (uri.scheme != 'https') {
      throw const FormatException('La URL debe empezar con https://');
    }
    if (uri.host.contains('youtube.com') || uri.host == 'youtu.be') {
      throw const FormatException(
        'YouTube no es compatible con el reproductor de la app',
      );
    }
    if (uri.host.endsWith('drive.google.com')) {
      final id =
          _drivePath.firstMatch(uri.path)?.group(1) ??
          _driveQuery.firstMatch(text)?.group(1);
      if (id == null) {
        throw const FormatException(
          'No se encontró el ID del archivo de Drive',
        );
      }
      return ResolvedVideoUrl(
        streamUrl: 'https://drive.google.com/uc?export=download&id=$id',
        source: VideoSource.googleDrive,
      );
    }
    if (uri.host.endsWith('.r2.dev') ||
        uri.host.endsWith('.r2.cloudflarestorage.com')) {
      return ResolvedVideoUrl(
        streamUrl: uri.toString(),
        source: VideoSource.r2,
      );
    }
    return ResolvedVideoUrl(
      streamUrl: uri.toString(),
      source: VideoSource.directMp4,
    );
  }
}
