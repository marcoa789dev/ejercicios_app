/// Una persona de la familia (members/{id}). Su id no cambia aunque se
/// vuelva a crear su cuenta de Auth, así su progreso nunca se pierde.
class Member {
  const new({
    required this.id,
    required this.displayName,
    required this.username,
    required this.order,
    this.colorHex = '#2E7D6B',
    this.avatar = 'person',
    this.isActive = true,
    this.authUid,
    this.lastPlaylistId,
  });

  final String id;
  final String displayName;
  final String username;
  final String colorHex;
  final String avatar;
  final int order;
  final bool isActive;

  /// Cuenta actual en Firebase Auth (`{username}@ejercicios.local`).
  final String? authUid;
  final String? lastPlaylistId;
}

/// Qué cuenta de Auth puede entrar y como quién (accounts/{authUid}).
class Account {
  const new({
    required this.memberId,
    required this.username,
    required this.isActive,
  });

  final String memberId;
  final String username;
  final bool isActive;
}

/// Una TV vinculada por QR a nombre de un integrante (tv_sessions/{tvUid}).
class TvSession {
  const new({
    required this.tvUid,
    required this.memberId,
    required this.expiresAt,
  });

  final String tvUid;
  final String memberId;
  final DateTime expiresAt;

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);
}
