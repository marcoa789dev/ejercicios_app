import 'dart:async';

import 'package:ejercicios_app/core/config.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:flutter/foundation.dart';

enum AdminAccess { signedOut, denied, admin }

/// Estado de la sesión para la guardia del router (§9.1): sin sesión,
/// sesión de otra cuenta ("Sin permisos") o el admin.
class AdminSession extends ChangeNotifier {
  new(this._auth, {this.adminUid = kAdminUid}) {
    _uid = _auth.currentUid;
    _sub = _auth.uidChanges().listen((uid) {
      if (uid == _uid) return;
      _uid = uid;
      notifyListeners();
    });
  }

  final AuthRepository _auth;
  final String adminUid;
  late final StreamSubscription<String?> _sub;
  String? _uid;

  AdminAccess get access => switch (_uid) {
    null => AdminAccess.signedOut,
    final uid when uid == adminUid => AdminAccess.admin,
    _ => AdminAccess.denied,
  };

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
