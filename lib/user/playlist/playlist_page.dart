import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/utils/duration_format.dart';
import 'package:ejercicios_app/ui_kit/feedback.dart';
import 'package:ejercicios_app/ui_kit/state_views.dart';
import 'package:ejercicios_app/user/next_up.dart';
import 'package:ejercicios_app/user/user_router.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Detalle de una semana: videos por día con su estado (§10.2).
class PlaylistPage extends StatefulWidget {
  const new({required this.member, required this.playlist, super.key});

  final Member member;
  final Playlist playlist;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  late final Stream<List<Video>> _videos = GetIt.I<CatalogRepository>()
      .watchVideos(widget.playlist.id);
  late final Stream<Map<String, PlaylistProgress>> _progress =
      GetIt.I<ProgressRepository>().watchProgress(widget.member.id);

  void _play(List<Video> videos, int index) => unawaited(
    context.push(
      UserRoutes.player,
      extra: (playlist: widget.playlist, videos: videos, index: index),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.playlist.title)),
    body: StreamBody<List<Video>>(
      stream: _videos,
      isEmpty: (v) => v.isEmpty,
      empty: const EmptyView(message: 'Esta semana todavía no tiene videos'),
      builder: (context, videos) =>
          StreamBuilder<Map<String, PlaylistProgress>>(
            stream: _progress,
            builder: (context, snap) =>
                _buildList(context, videos, snap.data?[widget.playlist.id]),
          ),
    ),
  );

  Widget _buildList(
    BuildContext context,
    List<Video> videos,
    PlaylistProgress? progress,
  ) {
    final theme = Theme.of(context);
    final p = widget.playlist;
    final next = nextUp(videos, progress);
    final total = videos.fold(Duration.zero, (sum, v) => sum + v.duration);
    final started =
        progress != null &&
        (progress.completedVideoIds.isNotEmpty ||
            progress.positionsSeconds.isNotEmpty);
    final days = <int, List<int>>{};
    for (final (i, v) in videos.indexed) {
      (days[v.dayNumber] ??= []).add(i);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (p.thumbnailUrl != null)
          SizedBox(
            // 16:9, pero sin pasar de 240 dp acostado o en la TV
            height: (MediaQuery.sizeOf(context).width * 9 / 16).clamp(0, 240),
            child: CachedNetworkImage(
              imageUrl: p.thumbnailUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (p.goal.isNotEmpty)
                Text(p.goal, style: theme.textTheme.titleMedium),
              Text(
                '${p.level.label} · ${videos.length} ejercicios · '
                '${formatTotal(total)}',
                style: theme.textTheme.bodyMedium,
              ),
              if (p.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.description),
              ],
              const SizedBox(height: 16),
              if (next == null)
                FilledButton.tonalIcon(
                  onPressed: () => _play(videos, 0),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Semana completada · Repetir'),
                )
              else
                FilledButton.icon(
                  onPressed: () => _play(videos, next.index),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    started
                        ? 'Continuar día ${videos[next.index].dayNumber}'
                        : 'Empezar',
                  ),
                ),
            ],
          ),
        ),
        for (final MapEntry(key: day, value: indexes) in days.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Día $day · ${indexes.length} '
              '${indexes.length == 1 ? 'ejercicio' : 'ejercicios'} · '
              '${formatTotal(_sum(videos, indexes))}',
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final i in indexes)
            _VideoRow(
              video: videos[i],
              completed: progress?.isCompleted(videos[i].id) ?? false,
              position: progress?.positionOf(videos[i].id),
              onTap: () => _play(videos, i),
            ),
        ],
      ],
    );
  }
}

Duration _sum(List<Video> videos, List<int> indexes) =>
    indexes.fold(Duration.zero, (s, i) => s + videos[i].duration);

class _VideoRow extends StatelessWidget {
  const new({
    required this.video,
    required this.completed,
    required this.position,
    required this.onTap,
  });

  final Video video;
  final bool completed;
  final Duration? position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = video;
    final at = completed ? null : position;
    final fraction = at == null || v.durationSeconds == 0
        ? null
        : (at.inSeconds / v.durationSeconds).clamp(0.0, 1.0);

    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 96,
          height: 54,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (v.thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: v.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Icon(Icons.movie_outlined),
                )
              else
                const Icon(Icons.movie_outlined),
              if (fraction != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(value: fraction, minHeight: 4),
                ),
            ],
          ),
        ),
      ),
      title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        at != null
            ? 'Visto ${formatClock(at)} de ${formatClock(v.duration)}'
            : formatClock(v.duration),
      ),
      trailing: Icon(
        completed ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: completed ? theme.colorScheme.primary : null,
      ),
    );
  }
}
