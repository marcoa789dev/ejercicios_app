import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class LoginState {
  const new();
}

final class LoginIdle extends LoginState {
  const new();
}

final class LoginLoading extends LoginState {
  const new();
}

final class LoginFailed extends LoginState {
  const new(this.failure);

  final Failure failure;
}

/// Inicio de sesión del admin con correo y contraseña. Al entrar no emite
/// nada: el router reacciona a la sesión nueva.
class LoginCubit extends Cubit<LoginState> {
  new(this._auth) : super(const LoginIdle());

  final AuthRepository _auth;

  Future<void> signIn(String email, String password) async {
    if (state is LoginLoading) return;
    emit(const LoginLoading());
    final result = await _auth.signInWithEmail(email, password);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => const LoginIdle(),
      Err(:final failure) => LoginFailed(failure),
    });
  }
}
