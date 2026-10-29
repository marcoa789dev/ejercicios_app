import 'dart:async';

import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:flutter/foundation.dart';

enum UserAccess { loading, signedOut, disabled, ready }

/// Quién usa la app (§10.2 "Splash"): sin sesión → login; cuenta no
/// registrada o desactivada → aviso; integrante activo → home.
///
/// Escucha `accounts/{uid}` y `members/{id}` en vivo, así que si el admin
/// desactiva a alguien la app reacciona al momento.
class UserSession extends ChangeNotifier {
  new(this._auth, this._members) {
    _authSub = _auth.uidChanges().listen(_onUid);
  }

  final AuthRepository _auth;
  final MemberRepository _members;
  late final StreamSubscription<String?> _authSub;
  StreamSubscription<Account?>? _accountSub;
  StreamSubscription<Member?>? _memberSub;

  UserAccess _access = UserAccess.loading;
  Member? _member;

  UserAccess get access => _access;

  /// El integrante, solo cuando [access] es [UserAccess.ready].
  Member? get member => _member;

  void _set(UserAccess access, [Member? member]) {
    if (access == _access && identical(member, _member)) return;
    _access = access;
    _member = member;
    notifyListeners();
  }

  void _onUid(String? uid) {
    unawaited(_accountSub?.cancel());
    unawaited(_memberSub?.cancel());
    _accountSub = null;
    _memberSub = null;
    if (uid == null) return _set(UserAccess.signedOut);
    _set(UserAccess.loading);
    _accountSub = _members
        .watchAccount(uid)
        .listen(_onAccount, onError: (_) => _set(UserAccess.disabled));
  }

  void _onAccount(Account? account) {
    unawaited(_memberSub?.cancel());
    _memberSub = null;
    if (account == null || !account.isActive) {
      return _set(UserAccess.disabled);
    }
    _memberSub = _members
        .watchMember(account.memberId)
        .listen(
          (m) => m == null || !m.isActive
              ? _set(UserAccess.disabled)
              : _set(UserAccess.ready, m),
          // Las reglas niegan la lectura en cuanto se desactiva la cuenta
          onError: (_) => _set(UserAccess.disabled),
        );
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    unawaited(_authSub.cancel());
    unawaited(_accountSub?.cancel());
    unawaited(_memberSub?.cancel());
    super.dispose();
  }
}
