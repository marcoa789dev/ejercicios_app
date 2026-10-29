import 'package:ejercicios_app/core/result.dart';
import 'package:ejercicios_app/ui_kit/state_views.dart';
import 'package:flutter/material.dart';

/// Mensaje en español para un [Failure].
String failureMessage(Failure f) => switch (f) {
  NetworkFailure() => 'Sin conexión. Revisa el internet e intenta de nuevo.',
  PermissionFailure() => 'No tienes permiso para hacer esto.',
  NotFoundFailure() => 'Ya no existe; quizá se borró.',
  AlreadyExistsFailure() => 'Ese usuario ya está ocupado.',
  NotEmptyFailure() => 'Todavía tiene elementos dentro.',
  InvalidCredentialsFailure() => 'El usuario o la contraseña no son correctos.',
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
