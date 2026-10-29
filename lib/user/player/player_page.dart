import 'dart:async';

import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/utils/duration_format.dart';
import 'package:ejercicios_app/core/utils/resume_policy.dart';
import 'package:ejercicios_app/user/player/progress_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Reproductor del teléfono (§10.2). Reproduce [videos] (activos y en orden)
/// empezando por [index], siempre en la resolución original del archivo.
class PlayerPage extends StatefulWidget {
  const new({
    required this.member,
    required this.playlist,
    required this.videos,
    required this.index,
    super.key,
  });

  final Member member;
  final Playlist playlist;
  final List<Video> videos;
  final int index;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  static const _initTimeout = Duration(seconds: 15);
  static const _speeds = [0.75, 1.0, 1.25];

  final ProgressRepository _progress = GetIt.I();
  late final Stream<Map<String, PlaylistProgress>> _progressStream = _progress
      .watchProgress(widget.member.id);

  late int _index = widget.index;
  VideoPlayerController? _controller;
  ProgressTracker? _tracker;
  String? _error;
  bool _wasPlaying = false;
  bool _ended = false;
  int _lastTickSecond = -1;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  double _speed = 1;
  Timer? _hideTimer;

  Video get _video => widget.videos[_index];
  bool get _isLast => _index == widget.videos.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    unawaited(
      GetIt.I<MemberRepository>().updateLastPlaylist(
        widget.member.id,
        widget.playlist.id,
      ),
    );
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    unawaited(_release(disposing: true));
    unawaited(WakelockPlus.disable());
    unawaited(SystemChrome.setPreferredOrientations([]));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // La app puede morir en segundo plano sin aviso: guardar ya
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flush();
      unawaited(_controller?.pause());
    }
  }

  /// Guarda el avance del video actual y libera el reproductor.
  ///
  /// El reproductor viejo se libera después de que la pantalla deja de
  /// mostrarlo, sin hacer esperar al siguiente video.
  Future<void> _release({bool disposing = false}) async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    c.removeListener(_onValue);
    if (c.value.isInitialized) {
      await _tracker?.flush(c.value.position);
    }
    if (disposing || !mounted) {
      unawaited(c.dispose());
      return;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(c.dispose()));
  }

  void _flush() {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      unawaited(_tracker?.flush(c.value.position));
    }
  }

  Future<void> _load() async {
    await _release();
    if (!mounted) return;
    setState(() {
      _error = null;
      _ended = false;
      _tracker = null;
      _lastTickSecond = -1;
      _wasPlaying = false;
    });

    final video = _video;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(video.streamUrl),
    );
    _controller = controller;
    try {
      await controller.initialize().timeout(_initTimeout);
    } on Object catch (_) {
      if (!mounted || _controller != controller) return;
      setState(
        () => _error =
            'No se pudo cargar el video. Revisa tu conexión a internet.',
      );
      return;
    }
    if (!mounted || _controller != controller) return;

    final duration = controller.value.duration > Duration.zero
        ? controller.value.duration
        : video.duration;
    // Desde la caché de Firestore: instantáneo y funciona sin red
    final all = await _progress.watchProgress(widget.member.id).first;
    final progress = all[widget.playlist.id];
    final completed = progress?.isCompleted(video.id) ?? false;
    final startAt = completed
        ? Duration.zero
        : ResumePolicy.startAt(
            saved: progress?.positionOf(video.id),
            duration: duration,
          );

    _tracker = ProgressTracker(
      repo: _progress,
      memberId: widget.member.id,
      playlistId: widget.playlist.id,
      videoId: video.id,
      duration: duration,
      alreadyCompleted: completed,
    );
    await controller.setPlaybackSpeed(_speed);
    if (startAt > Duration.zero) await controller.seekTo(startAt);
    controller.addListener(_onValue);
    await controller.play();
    if (!mounted) return;
    setState(() {});
    _scheduleHide();
    if (startAt > Duration.zero) _showResumed(startAt);
  }

  void _showResumed(Duration from) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Continuando desde ${formatClock(from)}'),
          action: SnackBarAction(
            label: 'Empezar de nuevo',
            onPressed: () {
              unawaited(_tracker?.restart());
              unawaited(_controller?.seekTo(Duration.zero));
            },
          ),
        ),
      );
  }

  void _onValue() {
    final c = _controller;
    final tracker = _tracker;
    if (c == null || tracker == null) return;
    final v = c.value;

    if (v.isPlaying && v.position.inSeconds != _lastTickSecond) {
      _lastTickSecond = v.position.inSeconds;
      unawaited(tracker.onTick(v.position));
    }
    if (_wasPlaying && !v.isPlaying) _flush();
    final ended =
        v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying;
    if (ended != _ended || _wasPlaying != v.isPlaying) {
      setState(() {
        _ended = ended;
        if (ended) _controlsVisible = true;
      });
    }
    _wasPlaying = v.isPlaying;
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      unawaited(c.pause());
    } else {
      if (_ended) unawaited(c.seekTo(Duration.zero));
      unawaited(c.play());
      _scheduleHide();
    }
  }

  Future<void> _seekTo(Duration position) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final max = c.value.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (position > max ? max : position);
    await c.seekTo(target);
    unawaited(_tracker?.flush(target));
    _scheduleHide();
  }

  void _seekBy(Duration offset) {
    final c = _controller;
    if (c == null) return;
    unawaited(_seekTo(c.value.position + offset));
  }

  void _cycleSpeed() {
    final next = _speeds[(_speeds.indexOf(_speed) + 1) % _speeds.length];
    setState(() => _speed = next);
    unawaited(_controller?.setPlaybackSpeed(next));
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  /// Pantalla completa con el botón. Girar el teléfono también la activa
  /// (ver `build`); al salir con el botón se regresa a vertical.
  Future<void> _setFullscreen({required bool full}) async {
    setState(() => _fullscreen = full);
    await SystemChrome.setPreferredOrientations(
      full
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(
      full ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (!full) {
      // Ya en vertical, se vuelve a permitir girar
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted && !_fullscreen) {
        await SystemChrome.setPreferredOrientations([]);
      }
    }
  }

  Future<void> _next() async {
    if (_isLast) {
      await _release();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.emoji_events_rounded, size: 48),
          title: const Text('¡Terminaste la semana!'),
          content: Text(
            'Completaste "${widget.playlist.title}". ¡Muy bien hecho!',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _index++);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Acostado (teléfono girado o TV) el video ocupa toda la pantalla:
    // video 16:9 + información no caben a lo alto
    final full =
        _fullscreen ||
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final player = _PlayerSurface(
      controller: _controller,
      error: _error,
      ended: _ended,
      controlsVisible: _controlsVisible,
      fullscreen: full,
      speed: _speed,
      onRetry: () => unawaited(_load()),
      onTap: _toggleControls,
      onTogglePlay: _togglePlay,
      onSeekBy: _seekBy,
      onSeekTo: (p) => unawaited(_seekTo(p)),
      onSpeed: _cycleSpeed,
      onFullscreen: () => unawaited(_setFullscreen(full: !full)),
    );

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) unawaited(_setFullscreen(full: false));
      },
      child: full
          ? Scaffold(backgroundColor: Colors.black, body: player)
          : Scaffold(
              appBar: AppBar(title: Text(widget.playlist.title)),
              body: Column(
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: player),
                  Expanded(child: _buildInfo(context)),
                ],
              ),
            ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final theme = Theme.of(context);
    final v = _video;
    final sameDay = widget.videos.where((x) => x.dayNumber == v.dayNumber);
    final position = sameDay.toList().indexOf(v) + 1;
    final reps = [
      if (v.sets != null) '${v.sets} series',
      if (v.reps != null) '${v.reps} repeticiones',
    ].join(' × ');

    // Los botones quedan fijos abajo: en un teléfono chico no hay que
    // desplazarse para encontrar "Siguiente ejercicio"
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _details(theme, v, position, sameDay.length, reps),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<Map<String, PlaylistProgress>>(
                    stream: _progressStream,
                    builder: (context, snap) {
                      final done =
                          snap.data?[widget.playlist.id]?.isCompleted(v.id) ??
                          false;
                      return OutlinedButton.icon(
                        onPressed: _tracker == null
                            ? null
                            : () => unawaited(
                                _tracker!.setCompleted(completed: !done),
                              ),
                        icon: Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                        ),
                        label: Text(
                          done ? 'Completado' : 'Marcar como completado',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => unawaited(_next()),
                    icon: Icon(
                      _isLast ? Icons.flag_rounded : Icons.skip_next_rounded,
                    ),
                    label: Text(
                      _isLast ? 'Terminar la semana' : 'Siguiente ejercicio',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _details(
    ThemeData theme,
    Video v,
    int position,
    int ofDay,
    String reps,
  ) => [
    Text(
      'Día ${v.dayNumber} · Ejercicio $position de $ofDay',
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
    ),
    const SizedBox(height: 4),
    Text(v.title, style: theme.textTheme.titleLarge),
    if (reps.isNotEmpty) ...[
      const SizedBox(height: 4),
      Text(reps, style: theme.textTheme.titleMedium),
    ],
    if (v.instructions.isNotEmpty)
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Instrucciones'),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(v.instructions)),
        ],
      ),
  ];
}

/// El video con sus controles encima.
class _PlayerSurface extends StatelessWidget {
  const new({
    required this.controller,
    required this.error,
    required this.ended,
    required this.controlsVisible,
    required this.fullscreen,
    required this.speed,
    required this.onRetry,
    required this.onTap,
    required this.onTogglePlay,
    required this.onSeekBy,
    required this.onSeekTo,
    required this.onSpeed,
    required this.onFullscreen,
  });

  final VideoPlayerController? controller;
  final String? error;
  final bool ended;
  final bool controlsVisible;
  final bool fullscreen;
  final double speed;
  final VoidCallback onRetry;
  final VoidCallback onTap;
  final VoidCallback onTogglePlay;
  final ValueChanged<Duration> onSeekBy;
  final ValueChanged<Duration> onSeekTo;
  final VoidCallback onSpeed;
  final VoidCallback onFullscreen;

  static const _step = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final Widget content;
    if (error != null) {
      // Compacto: en un teléfono parado el recuadro del video mide ~220 dp
      content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                autofocus: true,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    } else if (c == null || !c.value.isInitialized) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          // Relación de aspecto original, sin recortar ni deformar
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onDoubleTapDown: (d) {
              final box = context.size;
              if (box == null) return;
              onSeekBy(d.localPosition.dx < box.width / 2 ? -_step : _step);
            },
          ),
          if (controlsVisible || ended) _controls(context, c),
        ],
      );
    }
    return ColoredBox(color: Colors.black, child: content);
  }

  Widget _controls(BuildContext context, VideoPlayerController c) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (context, v, _) {
          final total = v.duration.inMilliseconds.toDouble();
          final pos = v.position.inMilliseconds
              .clamp(0, v.duration.inMilliseconds)
              .toDouble();
          return ColoredBox(
            color: Colors.black38,
            child: IconTheme(
              data: const IconThemeData(color: Colors.white, size: 32),
              child: Column(
                children: [
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Atrás 10 s',
                        onPressed: () => onSeekBy(-_step),
                        icon: const Icon(Icons.replay_10_rounded),
                      ),
                      IconButton(
                        tooltip: v.isPlaying ? 'Pausa' : 'Reproducir',
                        iconSize: 56,
                        onPressed: onTogglePlay,
                        icon: Icon(
                          ended
                              ? Icons.replay_rounded
                              : (v.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Adelante 10 s',
                        onPressed: () => onSeekBy(_step),
                        icon: const Icon(Icons.forward_10_rounded),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (v.isBuffering)
                    const LinearProgressIndicator(minHeight: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          max: total > 0 ? total : 1,
                          value: total > 0 ? pos : 0,
                          onChanged: (x) =>
                              c.seekTo(Duration(milliseconds: x.toInt())),
                          onChangeEnd: (x) =>
                              onSeekTo(Duration(milliseconds: x.toInt())),
                        ),
                      ),
                      Text(
                        '${formatClock(v.position)} / '
                        '${formatClock(v.duration)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: onSpeed,
                        child: Text(
                          speed == 1 ? '1x' : '${speed}x',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        tooltip: fullscreen
                            ? 'Salir de pantalla completa'
                            : 'Pantalla completa',
                        onPressed: onFullscreen,
                        icon: Icon(
                          fullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
}
