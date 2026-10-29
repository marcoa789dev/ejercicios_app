import 'package:cached_network_image/cached_network_image.dart';
import 'package:ejercicios_app/admin/widgets/admin_widgets.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// Crear (sin [playlist]) o editar una semana de la [category].
class PlaylistFormPage extends StatefulWidget {
  const new({required this.category, this.playlist, super.key});

  final Category category;
  final Playlist? playlist;

  @override
  State<PlaylistFormPage> createState() => _PlaylistFormPageState();
}

class _PlaylistFormPageState extends State<PlaylistFormPage> {
  final _form = GlobalKey<FormState>();
  late final Playlist? _old = widget.playlist;
  late final _title = TextEditingController(text: _old?.title);
  late final _week = TextEditingController(text: '${_old?.weekNumber ?? 1}');
  late final _description = TextEditingController(text: _old?.description);
  late final _goal = TextEditingController(text: _old?.goal);
  late final _thumbnail = TextEditingController(text: _old?.thumbnailUrl);
  late Level _level = _old?.level ?? Level.beginner;
  late bool _active = _old?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _week, _description, _goal, _thumbnail]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final thumb = _thumbnail.text.trim();
    final result = await GetIt.I<CatalogAdminRepository>().savePlaylist(
      Playlist(
        id: _old?.id ?? '',
        categoryId: widget.category.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        goal: _goal.text.trim(),
        thumbnailUrl: thumb.isEmpty ? null : thumb,
        level: _level,
        weekNumber: int.parse(_week.text),
        order: _old?.order ?? 0,
        isActive: _active,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (reportResult(context, result)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final noVideos = (_old?.totalVideos ?? 0) == 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_old == null ? 'Nueva semana' : 'Editar semana'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.category.name,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Ej. Semana 1: Movilidad',
                border: OutlineInputBorder(),
              ),
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe un título' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _week,
                    decoration: const InputDecoration(
                      labelText: 'Semana nº',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 ? 'Número ≥ 1' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<Level>(
                    initialValue: _level,
                    decoration: const InputDecoration(
                      labelText: 'Nivel',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final l in Level.values)
                        DropdownMenuItem(value: l, child: Text(l.label)),
                    ],
                    onChanged: (v) => setState(() => _level = v ?? _level),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _goal,
              decoration: const InputDecoration(
                labelText: 'Objetivo (opcional)',
                hintText: 'Ej. Recuperar rango de movimiento',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _thumbnail,
              decoration: const InputDecoration(
                labelText: 'URL de la portada (opcional)',
                hintText: 'https://…/portada.webp',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || t.startsWith('https://')
                    ? null
                    : 'Debe empezar con https://';
              },
            ),
            if (_thumbnail.text.trim().startsWith('https://'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: _thumbnail.text.trim(),
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const Center(
                        child: Text('No se pudo cargar la imagen'),
                      ),
                    ),
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible para la familia'),
              subtitle: _active && noVideos
                  ? const Text('Todavía no tiene videos')
                  : null,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
