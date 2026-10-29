import 'package:ejercicios_app/core/result.dart';
import 'package:ejercicios_app/ui_kit/palette.dart';
import 'package:ejercicios_app/ui_kit/state_views.dart';
import 'package:flutter/material.dart';

/// Mensaje en español para un [Failure].
String failureMessage(Failure f) => switch (f) {
  NetworkFailure() => 'Sin conexión. Revisa el internet e intenta de nuevo.',
  PermissionFailure() => 'No tienes permiso para hacer esto.',
  NotFoundFailure() => 'Ya no existe; quizá se borró.',
  AlreadyExistsFailure() => 'Ese usuario ya está ocupado.',
  NotEmptyFailure() => 'Todavía tiene elementos dentro.',
  InvalidCredentialsFailure() => 'Correo o contraseña incorrectos.',
  TooManyAttemptsFailure() =>
    'Demasiados intentos. Espera unos minutos y vuelve a intentar.',
  ValidationFailure(detail: 'weak-password') =>
    'La contraseña es muy débil (mínimo 6 caracteres).',
  ValidationFailure() => 'Algún dato no es válido.',
  UnknownFailure() => 'Algo salió mal: ${f.detail ?? f.code}',
};

/// Muestra un aviso si [result] falló. Devuelve `true` si salió bien.
bool reportResult(BuildContext context, Result<Object?> result, {String? ok}) {
  final messenger = ScaffoldMessenger.of(context);
  switch (result) {
    case Ok():
      if (ok != null) messenger.showSnackBar(SnackBar(content: Text(ok)));
      return true;
    case Err(:final failure):
      messenger.showSnackBar(SnackBar(content: Text(failureMessage(failure))));
      return false;
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Borrar',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Cuerpo de una pantalla que escucha un stream: cargando, error, vacía o
/// datos.
class StreamBody<T> extends StatelessWidget {
  const new({
    required this.stream,
    required this.builder,
    this.isEmpty,
    this.empty,
    super.key,
  });

  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: stream,
    builder: (context, snap) {
      if (snap.hasError) {
        return const ErrorView(
          message:
              'No se pudo cargar. Si acabas de crear la base, '
              'revisa las reglas y los índices de Firestore.',
        );
      }
      final data = snap.data;
      if (data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (empty != null && (isEmpty?.call(data) ?? false)) return empty!;
      return builder(context, data);
    },
  );
}

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
