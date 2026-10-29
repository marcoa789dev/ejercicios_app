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

/// Home del teléfono (§10.2): "Continuar", categorías y semanas con su %.
class HomePage extends StatefulWidget {
  const new({required this.member, super.key});

  final Member member;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CatalogRepository _catalog = GetIt.I();
  late final Stream<List<Category>> _categories = _catalog.watchCategories();
  late final Stream<Map<String, PlaylistProgress>> _progress =
      GetIt.I<ProgressRepository>().watchProgress(widget.member.id);

  String? _categoryId;
  Stream<List<Playlist>>? _playlists;

  void _select(String categoryId) {
    if (categoryId == _categoryId) return;
    _categoryId = categoryId;
    _playlists = _catalog.watchPlaylists(categoryId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Hola, ${widget.member.displayName}'),
      actions: [
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => unawaited(context.push(UserRoutes.settings)),
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    ),
    body: StreamBody<List<Category>>(
      stream: _categories,
      isEmpty: (list) => list.isEmpty,
      empty: const EmptyView(
        message:
            'Todavía no hay rutinas. Pídele al administrador que las '
            'agregue.',
      ),
      builder: (context, categories) {
        if (!categories.any((c) => c.id == _categoryId)) {
          _select(categories.first.id);
        }
        return StreamBuilder<Map<String, PlaylistProgress>>(
          stream: _progress,
          builder: (context, snap) {
            final progress = snap.data ?? const {};
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (_continuePlaylistId(progress) case final id?)
                  ContinueCard(
                    key: ValueKey(id),
                    member: widget.member,
                    playlistId: id,
                    progress: progress[id],
                  ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final c in categories)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: ChoiceChip(
                            label: Text(c.name),
                            selected: c.id == _categoryId,
                            onSelected: (_) => setState(() => _select(c.id)),
                          ),
                        ),
                    ],
                  ),
                ),
                StreamBuilder<List<Playlist>>(
                  stream: _playlists,
                  builder: (context, snap) {
                    final playlists = snap.data;
                    if (playlists == null) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (playlists.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Esta categoría todavía no tiene semanas.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final p in playlists)
                          PlaylistCard(
                            playlist: p,
                            fraction: cardFraction(p, progress[p.id]),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    ),
  );

  /// La playlist vista más recientemente, o la última que abrió.
  String? _continuePlaylistId(Map<String, PlaylistProgress> progress) {
    final withVideo = progress.values.where((p) => p.lastVideoId != null);
    if (withVideo.isNotEmpty) {
      final epoch = DateTime.fromMillisecondsSinceEpoch(0);
      return withVideo
          .reduce(
            (a, b) =>
                (a.updatedAt ?? epoch).isAfter(b.updatedAt ?? epoch) ? a : b,
          )
          .playlistId;
    }
    return widget.member.lastPlaylistId;
  }
}

/// "Continuar": el video a medias en su segundo exacto, o el siguiente
/// pendiente de esa semana. No se muestra si ya terminó todo.
class ContinueCard extends StatefulWidget {
  const new({
    required this.member,
    required this.playlistId,
    required this.progress,
    super.key,
  });

  final Member member;
  final String playlistId;
  final PlaylistProgress? progress;

  @override
  State<ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<ContinueCard> {
  final CatalogRepository _catalog = GetIt.I();
  late final Stream<Playlist?> _playlist = _catalog.watchPlaylist(
    widget.playlistId,
  );
  late final Stream<List<Video>> _videos = _catalog.watchVideos(
    widget.playlistId,
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<Playlist?>(
    stream: _playlist,
    builder: (context, ps) => StreamBuilder<List<Video>>(
      stream: _videos,
      builder: (context, vs) {
        final playlist = ps.data;
        final videos = vs.data;
        if (playlist == null || !playlist.isActive || videos == null) {
          return const SizedBox.shrink();
        }
        final next = nextUp(videos, widget.progress);
        if (next == null) return const SizedBox.shrink();
        final video = videos[next.index];
        final at = next.resumeAt;
        final theme = Theme.of(context);

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: theme.colorScheme.primaryContainer,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => unawaited(
              context.push(
                UserRoutes.player,
                extra: (playlist: playlist, videos: videos, index: next.index),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          at != null ? 'Continuar' : 'Siguiente ejercicio',
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '${playlist.title} · Día ${video.dayNumber}'
                          '${at != null ? ' · ${formatClock(at)} de '
                                    '${formatClock(video.duration)}' : ''}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (at != null && video.durationSeconds > 0) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: at.inSeconds / video.durationSeconds,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Tarjeta de una semana: portada 16:9, título, nivel, duración y %.
class PlaylistCard extends StatelessWidget {
  const new({required this.playlist, required this.fraction, super.key});

  final Playlist playlist;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = playlist;
    final done = fraction >= 1;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push(UserRoutes.playlist, extra: p)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: p.thumbnailUrl == null
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.fitness_center_rounded, size: 48),
                    )
                  : CachedNetworkImage(
                      imageUrl: p.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const Icon(Icons.fitness_center_rounded, size: 48),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (done)
                        Icon(
                          Icons.check_circle_rounded,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.level.label} · ${p.totalVideos} ejercicios · '
                    '${formatTotal(p.totalDuration)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: LinearProgressIndicator(value: fraction)),
                      const SizedBox(width: 8),
                      Text('${(fraction * 100).round()} %'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
