import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Prueba mínima de reproducción desde R2 (Sprint 0).
///
/// Muestra la resolución real del archivo para confirmar que se reproduce
/// la original.
///
/// Controles: OK / Enter / Espacio / Play-Pausa = reproducir o pausar;
/// ← / → = ∓10 s.
class VideoSmokeTestPage extends StatefulWidget {
  const new({required this.url, super.key});

  final String url;

  @override
  State<VideoSmokeTestPage> createState() => _VideoSmokeTestPageState();
}

class _VideoSmokeTestPageState extends State<VideoSmokeTestPage> {
  static const _initTimeout = Duration(seconds: 15);
  static const _seekStep = Duration(seconds: 10);

  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.url.isEmpty) {
      _error =
          'No hay URL de prueba. '
          'Compila con --dart-define=TEST_VIDEO_URL=https://...';
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    unawaited(_initialize(controller));
  }

  Future<void> _initialize(VideoPlayerController controller) async {
    try {
      await controller.initialize().timeout(_initTimeout);
      await controller.play();
      if (mounted) setState(() {});
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'No se pudo reproducir: $e');
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    unawaited(c.value.isPlaying ? c.pause() : c.play());
  }

  void _seekBy(Duration offset) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    unawaited(c.seekTo(c.value.position + offset));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(_seekStep);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      _seekBy(-_seekStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: _togglePlay,
          child: Center(child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          error,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }
    final c = _controller!;
    if (!c.value.isInitialized) {
      return const CircularProgressIndicator();
    }
    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        // Relación de aspecto original, sin recortar ni deformar
        AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (context, value, _) => Container(
            color: Colors.black54,
            padding: const EdgeInsets.all(12),
            child: Text(
              '${value.size.width.toInt()}×${value.size.height.toInt()}  ·  '
              '${_format(value.position)} / ${_format(value.duration)}  ·  '
              '${value.isPlaying ? 'Reproduciendo' : 'Pausa'}'
              '${value.isBuffering ? ' (cargando…)' : ''}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}
