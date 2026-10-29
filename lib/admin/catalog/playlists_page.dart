import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ejercicios_app/admin/admin_router.dart';
import 'package:ejercicios_app/admin/widgets/admin_widgets.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/utils/duration_format.dart';
import 'package:ejercicios_app/ui_kit/state_views.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

enum _PlaylistAction { edit, duplicate, toggle, delete }

/// Semanas de una categoría, reordenables.
class PlaylistsPage extends StatefulWidget {
  const new({required this.category, super.key});

  final Category category;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final CatalogAdminRepository _admin = GetIt.I();
  late final Stream<List<Playlist>> _stream = GetIt.I<CatalogRepository>()
      .watchPlaylists(widget.category.id, includeInactive: true);
  List<Playlist>? _pending;

  void _openForm([Playlist? p]) => unawaited(
    context.push(
      AdminRoutes.playlistForm,
      extra: (category: widget.category, playlist: p),
    ),
  );

  Future<void> _reorder(List<Playlist> list, int from, int to) async {
    final next = [...list];
    next.insert(to, next.removeAt(from));
    setState(() => _pending = next);
    final result = await _admin.reorderPlaylists(next);
    if (!mounted) return;
    setState(() => _pending = null);
    reportResult(context, result);
  }

  Future<void> _duplicate(Playlist p) async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _TitleDialog(initial: '${p.title} (copia)'),
    );
    if (title == null || !mounted) return;
    final result = await _admin.duplicatePlaylist(p.id, newTitle: title);
    if (!mounted) return;
    reportResult(
      context,
      result,
      ok: 'Copia creada (desactivada). Revísala y actívala.',
    );
  }

  Future<void> _onAction(Playlist p, _PlaylistAction action) async {
    switch (action) {
      case _PlaylistAction.edit:
        _openForm(p);
      case _PlaylistAction.duplicate:
        await _duplicate(p);
      case _PlaylistAction.toggle:
        final result = await _admin.setPlaylistActive(
          p.id,
          active: !p.isActive,
        );
        if (mounted) reportResult(context, result);
      case _PlaylistAction.delete:
        final ok = await confirm(
          context,
          title: 'Borrar "${p.title}"',
          message:
              'Se borrarán también sus ${p.totalVideos} videos del catálogo '
              '(los archivos en R2 no se tocan). No se puede deshacer.',
        );
        if (!ok || !mounted) return;
        final result = await _admin.deletePlaylist(p.id);
        if (mounted) reportResult(context, result, ok: 'Semana borrada');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.category.name)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _openForm,
      icon: const Icon(Icons.add),
      label: const Text('Semana'),
    ),
    body: StreamBody<List<Playlist>>(
      stream: _stream,
      isEmpty: (list) => list.isEmpty,
      empty: EmptyView(
        message: 'Esta categoría no tiene semanas',
        actionLabel: 'Crear la primera',
        onAction: _openForm,
      ),
      builder: (context, data) {
        final list = _pending ?? data;
        return ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          onReorderItem: (from, to) => unawaited(_reorder(list, from, to)),
          itemBuilder: (context, i) {
            final p = list[i];
            return ListTile(
              key: ValueKey(p.id),
              leading: _Thumb(url: p.thumbnailUrl),
              title: Text(p.title),
              subtitle: Text(
                'Semana ${p.weekNumber} · ${p.level.label}\n'
                '${p.totalVideos} videos · ${formatTotal(p.totalDuration)}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!p.isActive) const StatusChip('Inactiva'),
                  PopupMenuButton<_PlaylistAction>(
                    onSelected: (a) => unawaited(_onAction(p, a)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _PlaylistAction.edit,
                        child: Text('Editar'),
                      ),
                      const PopupMenuItem(
                        value: _PlaylistAction.duplicate,
                        child: Text('Duplicar'),
                      ),
                      PopupMenuItem(
                        value: _PlaylistAction.toggle,
                        child: Text(p.isActive ? 'Desactivar' : 'Activar'),
                      ),
                      const PopupMenuItem(
                        value: _PlaylistAction.delete,
                        child: Text('Borrar'),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () =>
                  unawaited(context.push(AdminRoutes.videos, extra: p)),
            );
          },
        );
      },
    ),
  );
}

class _Thumb extends StatelessWidget {
  const new({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.video_library_outlined),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 72,
        height: 40,
        child: url == null
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _TitleDialog extends StatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Duplicar semana'),
    content: TextField(
      controller: _text,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Título de la copia'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          final t = _text.text.trim();
          if (t.isNotEmpty) Navigator.pop(context, t);
        },
        child: const Text('Duplicar'),
      ),
    ],
  );
}
