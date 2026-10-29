import 'package:ejercicios_app/admin/widgets/admin_widgets.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/ui_kit/palette.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// Crear (sin [category]) o editar una categoría.
class CategoryFormPage extends StatefulWidget {
  const new({this.category, super.key});

  final Category? category;

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _description = TextEditingController(
    text: widget.category?.description,
  );
  late String? _icon = widget.category?.icon;
  late String _color = widget.category?.colorHex ?? kPaletteHex.first;
  late bool _active = widget.category?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final old = widget.category;
    final result = await GetIt.I<CatalogAdminRepository>().saveCategory(
      Category(
        id: old?.id ?? '',
        name: _name.text.trim(),
        description: _description.text.trim(),
        icon: _icon,
        colorHex: _color,
        order: old?.order ?? 0,
        isActive: _active,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (reportResult(context, result)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.category == null ? 'Nueva categoría' : 'Editar categoría',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej. Rodilla',
              border: OutlineInputBorder(),
            ),
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Descripción (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const FormSection('Ícono'),
          IconPicker(
            icons: kCategoryIcons,
            value: _icon,
            onChanged: (v) => setState(() => _icon = v),
          ),
          const FormSection('Color'),
          ColorPicker(
            value: _color,
            onChanged: (v) => setState(() => _color = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Visible para la familia'),
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
