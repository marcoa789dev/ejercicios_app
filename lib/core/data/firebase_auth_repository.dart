import 'package:ejercicios_app/core/data/auth_errors.dart';
import 'package:ejercicios_app/core/data/firestore_errors.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:ejercicios_app/core/utils/username.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseAuthRepository implements AuthRepository {
  new(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<Result<void>> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(failureFromAuth(e));
    }
  }

  @override
  Future<Result<void>> changePassword(String current, String next) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) return const Err(PermissionFailure());
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: current),
      );
      await user.updatePassword(next);
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(failureFromAuth(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Crea la cuenta en una segunda instancia de Firebase para no cerrar la
/// sesión del admin (§12.2).
class FirebaseAccountCreator implements AccountCreator {
  new(this._options);

  final FirebaseOptions _options;

  @override
  Future<String> createAccount(String username, String password) async {
    // Nombre único por si una instancia anterior no se borró
    final app = await Firebase.initializeApp(
      name: 'account-creator-${DateTime.now().microsecondsSinceEpoch}',
      options: _options,
    );
    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final cred = await auth.createUserWithEmailAndPassword(
        email: emailForUsername(username),
        password: password,
      );
      await auth.signOut();
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw FailureException(failureFromAuth(e));
    } finally {
      await app.delete();
    }
  }
}
