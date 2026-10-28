import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/core/result.dart';

/// Ejecuta una escritura y traduce los errores de Firebase a [Failure].
Future<Result<T>> guardFirestore<T>(Future<T> Function() action) async {
  try {
    return Ok(await action());
  } on FirebaseException catch (e) {
    return Err(failureFromFirebase(e));
  }
}

Failure failureFromFirebase(FirebaseException e) => switch (e.code) {
  'permission-denied' || 'unauthenticated' => PermissionFailure(e.message),
  'unavailable' || 'deadline-exceeded' => NetworkFailure(e.message),
  'not-found' => NotFoundFailure(e.message),
  'invalid-argument' || 'failed-precondition' => ValidationFailure(e.message),
  _ => UnknownFailure('${e.code}: ${e.message}'),
};
