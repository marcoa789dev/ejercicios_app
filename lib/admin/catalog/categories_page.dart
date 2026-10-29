import 'dart:async';

import 'package:ejercicios_app/admin/admin_router.dart';
import 'package:ejercicios_app/admin/widgets/admin_widgets.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:ejercicios_app/ui_kit/palette.dart';
import 'package:ejercicios_app/ui_kit/state_views.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

enum _CategoryAction { edit, toggle, delete }

/// Inicio de la Admin App: categorías reordenables (mantener presionado y
/// arrastrar).
class CategoriesPage extends StatefulWidget {
  const new({required this.onSignOut, super.key});

  final Future<void> Function() onSignOut;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final CatalogAdminRepository _admin = GetIt.I();
  late final Stream<List<Category>> _stream = GetIt.I<CatalogRepository>()
      .watchCategories(includeInactive: true);

  /// Orden nuevo mientras se guarda; si falla, vuelve el del servidor.
  List<Category>? _pending;

  Future<void> _reorder(List<Category> list, int from, int to) async {
    final next = [...list];
    next.insert(to, next.removeAt(from));
    setState(() => _pending = next);
    final result = await _admin.reorderCategories(next);
    if (!mounted) return;
    setState(() => _pending = null);
    reportResult(context, result);
  }

  Future<void> _onAction(Category c, _CategoryAction action) async {
    switch (action) {
      case _CategoryAction.edit:
        unawaited(context.push(AdminRoutes.categoryForm, extra: c));
      case _CategoryAction.toggle:
        final result = await _admin.setCategoryActive(
          c.id,
          active: !c.isActive,
        );
        if (mounted) reportResult(context, result);
      case _CategoryAction.delete:
        final ok = await confirm(
          context,
          title: 'Borrar "${c.name}"',
          message:
              'Solo se puede borrar si no tiene semanas. '
              'Si solo quieres ocultarla, desactívala.',
        );
        if (!ok || !mounted) return;
        final result = await _admin.deleteCategory(c.id);
        if (!mounted) return;
        if (result case Err(failure: NotEmptyFailure())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tiene semanas. Bórralas primero o desactiva la categoría.',
              ),
            ),
          );
        } else {
          reportResult(context, result, ok: 'Categoría borrada');
        }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Categorías'),
      actions: [
        IconButton(
          tooltip: 'Integrantes',
          onPressed: () => unawaited(context.push(AdminRoutes.members)),
          icon: const Icon(Icons.people_alt_rounded),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => unawaited(widget.onSignOut()),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => unawaited(context.push(AdminRoutes.categoryForm)),
      icon: const Icon(Icons.add),
      label: const Text('Categoría'),
    ),
    body: StreamBody<List<Category>>(
      stream: _stream,
      isEmpty: (list) => list.isEmpty,
      empty: EmptyView(
        message: 'Todavía no hay categorías',
        actionLabel: 'Crear la primera',
        onAction: () => unawaited(context.push(AdminRoutes.categoryForm)),
      ),
      builder: (context, data) {
        final list = _pending ?? data;
        return ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: list.length,
          onReorderItem: (from, to) => unawaited(_reorder(list, from, to)),
          itemBuilder: (context, i) {
            final c = list[i];
            return ListTile(
              key: ValueKey(c.id),
              leading: CircleAvatar(
                backgroundColor: colorFromHex(c.colorHex),
                foregroundColor: Colors.white,
                child: Icon(categoryIcon(c.icon)),
              ),
              title: Text(c.name),
              subtitle: c.description.isEmpty ? null : Text(c.description),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!c.isActive) const StatusChip('Inactiva'),
                  PopupMenuButton<_CategoryAction>(
                    onSelected: (a) => unawaited(_onAction(c, a)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _CategoryAction.edit,
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: _CategoryAction.toggle,
                        child: Text(c.isActive ? 'Desactivar' : 'Activar'),
                      ),
                      const PopupMenuItem(
                        value: _CategoryAction.delete,
                        child: Text('Borrar'),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () =>
                  unawaited(context.push(AdminRoutes.playlists, extra: c)),
            );
          },
        );
      },
    ),
  );
}
