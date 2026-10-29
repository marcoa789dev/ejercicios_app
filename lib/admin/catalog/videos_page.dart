import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ejercicios_app/admin/admin_router.dart';
import 'package:ejercicios_app/admin/catalog/video_arrangement.dart';
import 'package:ejercicios_app/admin/widgets/admin_widgets.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/utils/duration_format.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

enum _VideoAction { edit, toggle, delete }

/// Videos de una semana agrupados por día. Arrastrar desde el asa ≡ los
/// reordena o los cambia de día.
class VideosPage extends StatefulWidget {
  const new({required this.playlist, super.key});

  final Playlist playlist;

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  final CatalogAdminRepository _admin = GetIt.I();
  late final Stream<List<Video>> _stream = GetIt.I<CatalogRepository>()
      .watchVideos(widget.playlist.id, includeInactive: true);
  List<VideoRow>? _pending;

  void _openForm({Video? video, int day = 1}) => unawaited(
    context.push(
      AdminRoutes.videoForm,
      extra: (playlist: widget.playlist, video: video, day: day),
    ),
  );

  Future<void> _move(List<VideoRow> rows, int from, int to) async {
    final moved = moveRow(rows, from, to);
    final changed = moved.changed;
    if (changed.isEmpty) return;
    setState(() => _pending = moved.rows);
    final result = await _admin.arrangeVideos(widget.playlist.id, changed);
    if (!mounted) return;
    setState(() => _pending = null);
    reportResult(context, result);
  }

  Future<void> _onAction(Video v, _VideoAction action) async {
    switch (action) {
      case _VideoAction.edit:
        _openForm(video: v, day: v.dayNumber);
      case _VideoAction.toggle:
        final result = await _admin.setVideoActive(v, active: !v.isActive);
        if (mounted) reportResult(context, result);
      case _VideoAction.delete:
        final ok = await confirm(
          context,
          title: 'Borrar "${v.title}"',
          message:
              'Se quita del catálogo (el archivo en R2 no se toca). '
              'Si solo quieres ocultarlo, desactívalo.',
        );
        if (!ok || !mounted) return;
        final result = await _admin.deleteVideo(v);
        if (mounted) reportResult(context, result, ok: 'Video borrado');
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Video>>(
    stream: _stream,
    builder: (context, snap) {
      final videos = snap.data;
      final active = videos?.where((v) => v.isActive).toList() ?? const [];
      final total = active.fold(Duration.zero, (sum, v) => sum + v.duration);
      // Siguiente día sin videos, para agregar rápido una semana completa
      final lastDay = active.fold(
        0,
        (m, v) => v.dayNumber > m ? v.dayNumber : m,
      );
      final nextDay = lastDay < kDaysPerWeek ? lastDay + 1 : kDaysPerWeek;

      return Scaffold(
        appBar: AppBar(
          title: Text(widget.playlist.title),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(24),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${active.length} videos activos · ${formatTotal(total)}',
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(day: nextDay),
          icon: const Icon(Icons.add),
          label: Text('Video al día $nextDay'),
        ),
        body: StreamBody<List<Video>>(
          stream: _stream,
          builder: (context, data) {
            final rows = _pending ?? buildRows(data);
            return ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: rows.length,
              onReorderItem: (from, to) => unawaited(_move(rows, from, to)),
              itemBuilder: (context, i) => switch (rows[i]) {
                DayHeader(:final day) => _DayHeaderTile(
                  key: ValueKey('day-$day'),
                  day: day,
                  onAdd: () => _openForm(day: day),
                ),
                VideoItem(:final video) => _VideoTile(
                  key: ValueKey(video.id),
                  index: i,
                  video: video,
                  onTap: () => _openForm(video: video, day: video.dayNumber),
                  onAction: (a) => unawaited(_onAction(video, a)),
                ),
              },
            );
          },
        ),
      );
    },
  );
}

class _DayHeaderTile extends StatelessWidget {
  const new({required this.day, required this.onAdd, super.key});

  final int day;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainer,
    padding: const EdgeInsets.only(left: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Día $day',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar'),
        ),
      ],
    ),
  );
}

class _VideoTile extends StatelessWidget {
  const new({
    required this.index,
    required this.video,
    required this.onTap,
    required this.onAction,
    super.key,
  });

  final int index;
  final Video video;
  final VoidCallback onTap;
  final ValueChanged<_VideoAction> onAction;

  @override
  Widget build(BuildContext context) {
    final v = video;
    final reps = [
      if (v.sets != null) '${v.sets} series',
      if (v.reps != null) '${v.reps} reps',
    ].join(' × ');
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 72,
          height: 40,
          child: v.thumbnailUrl == null
              ? const Icon(Icons.movie_outlined)
              : CachedNetworkImage(
                  imageUrl: v.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const Icon(Icons.movie_outlined),
                ),
        ),
      ),
      title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [formatClock(v.duration), if (reps.isNotEmpty) reps].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!v.isActive) const StatusChip('Inactivo'),
          PopupMenuButton<_VideoAction>(
            onSelected: onAction,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _VideoAction.edit,
                child: Text('Editar'),
              ),
              PopupMenuItem(
                value: _VideoAction.toggle,
                child: Text(v.isActive ? 'Desactivar' : 'Activar'),
              ),
              const PopupMenuItem(
                value: _VideoAction.delete,
                child: Text('Borrar'),
              ),
            ],
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle_rounded),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
