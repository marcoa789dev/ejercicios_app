/// Resultado de una operación que puede fallar sin lanzar excepciones.
sealed class Result<T> {
  const new();

  bool get isOk => this is Ok<T>;
}

final class Ok<T> extends Result<T> {
  const new(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const new(this.failure);

  final Failure failure;
}

/// Errores de dominio, ya traducidos (la UI decide el mensaje).
sealed class Failure {
  const new([this.detail]);

  final String? detail;

  /// Código estable para logs y Crashlytics.
  String get code;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}

final class NetworkFailure extends Failure {
  const new([super.detail]);

  @override
  String get code => 'network';
}

final class PermissionFailure extends Failure {
  const new([super.detail]);

  @override
  String get code => 'permission';
}

final class NotFoundFailure extends Failure {
  const new([super.detail]);

  @override
  String get code => 'not_found';
}

final class ValidationFailure extends Failure {
  const new([super.detail]);

  @override
  String get code => 'validation';
}

final class UnknownFailure extends Failure {
  const new([super.detail]);

  @override
  String get code => 'unknown';
}
