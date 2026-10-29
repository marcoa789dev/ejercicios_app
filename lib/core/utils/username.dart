import 'dart:math';

/// La familia solo ve el usuario (`mama`); Firebase Auth guarda
/// `mama@ejercicios.local` (ADR-014).
const kUsernameDomain = 'ejercicios.local';

final _username = RegExp(r'^[a-z0-9._-]{3,20}$');

String emailForUsername(String username) =>
    '${username.trim().toLowerCase()}@$kUsernameDomain';

/// `null` si es válido; si no, el mensaje para el formulario.
String? validateUsername(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Escribe un usuario';
  if (v.length < 3 || v.length > 20) return 'Entre 3 y 20 caracteres';
  if (!_username.hasMatch(v)) {
    return 'Solo minúsculas, números, punto, guion y guion bajo';
  }
  return null;
}

String? validatePassword(String? value) =>
    (value ?? '').length < 6 ? 'Mínimo 6 caracteres' : null;

/// Contraseña fácil de dictar: sin 0/O, 1/l/I.
String generatePassword({int length = 8, Random? random}) {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = random ?? Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}
