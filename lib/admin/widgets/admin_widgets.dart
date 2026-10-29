import 'package:ejercicios_app/ui_kit/palette.dart';
import 'package:flutter/material.dart';

export 'package:ejercicios_app/ui_kit/feedback.dart';

/// Chip pequeño de estado (ej. "Inactiva").
class StatusChip extends StatelessWidget {
  const new(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
      ),
    );
  }
}

/// Selector de color de la paleta fija.
class ColorPicker extends StatelessWidget {
  const new({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final hex in kPaletteHex)
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => onChanged(hex),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: colorFromHex(hex),
            child: hex == value
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        ),
    ],
  );
}

/// Selector de ícono de un mapa clave → ícono.
class IconPicker extends StatelessWidget {
  const new({
    required this.icons,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Map<String, IconData> icons;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final MapEntry(:key, value: icon) in icons.entries)
        IconButton.outlined(
          isSelected: key == value,
          onPressed: () => onChanged(key),
          icon: Icon(icon),
        ),
    ],
  );
}

/// Separador de secciones en un formulario.
class FormSection extends StatelessWidget {
  const new(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}
