import 'package:ejercicios_app/core/result.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Traduce los códigos de Firebase Auth a [Failure].
Failure failureFromAuth(FirebaseAuthException e) => switch (e.code) {
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'invalid-email' => const InvalidCredentialsFailure(),
  'user-disabled' => PermissionFailure(e.message),
  'too-many-requests' => const TooManyAttemptsFailure(),
  'network-request-failed' => NetworkFailure(e.message),
  'email-already-in-use' => const AlreadyExistsFailure(),
  'weak-password' => const ValidationFailure('weak-password'),
  _ => UnknownFailure('${e.code}: ${e.message}'),
};
