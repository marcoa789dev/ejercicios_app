import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/result.dart';

/// Lectura del catálogo (User App y Admin App).
abstract interface class CatalogRepository {
  Stream<List<Category>> watchCategories({bool includeInactive = false});

  /// Una playlist por id; `null` si no existe.
  Stream<Playlist?> watchPlaylist(String id);

  Stream<List<Playlist>> watchPlaylists(
    String categoryId, {
    bool includeInactive = false,
  });

  /// Ordenados por día y luego por orden dentro del día.
  Stream<List<Video>> watchVideos(
    String playlistId, {
    bool includeInactive = false,
  });
}

/// Nueva posición de un video al reordenar o moverlo de día.
typedef VideoSlot = ({String id, int dayNumber, int order});

/// Escritura del catálogo (solo Admin App).
///
/// Un `id` vacío en `save*` crea el documento y lo pone al final de su lista.
/// Cada cambio en los videos de una playlist recalcula sus agregados
/// (`total_videos`, `total_duration_seconds`, `days_count`) con los videos
/// activos.
abstract interface class CatalogAdminRepository {
  Future<Result<String>> saveCategory(Category category);

  /// [ordered] en el orden nuevo; solo se escriben los que cambiaron.
  Future<Result<void>> reorderCategories(List<Category> ordered);
  Future<Result<void>> setCategoryActive(String id, {required bool active});

  /// [NotEmptyFailure] si la categoría todavía tiene playlists.
  Future<Result<void>> deleteCategory(String id);

  Future<Result<String>> savePlaylist(Playlist playlist);
  Future<Result<void>> reorderPlaylists(List<Playlist> ordered);
  Future<Result<void>> setPlaylistActive(String id, {required bool active});

  /// Copia la playlist y sus videos como la semana siguiente, desactivada
  /// para revisarla antes de mostrarla a la familia.
  Future<Result<String>> duplicatePlaylist(
    String id, {
    required String newTitle,
  });

  /// Borra la playlist y todos sus videos.
  Future<Result<void>> deletePlaylist(String id);

  Future<Result<String>> saveVideo(Video video);
  Future<Result<void>> arrangeVideos(String playlistId, List<VideoSlot> slots);
  Future<Result<void>> setVideoActive(Video video, {required bool active});
  Future<Result<void>> deleteVideo(Video video);
}

/// Crea cuentas de Firebase Auth sin cerrar la sesión del admin (ADR-013).
abstract interface class AccountCreator {
  /// Devuelve el UID nuevo. Lanza `FailureException` con
  /// [AlreadyExistsFailure] si el usuario ya existe en Auth.
  Future<String> createAccount(String username, String password);
}

/// Integrantes, sus cuentas y las TVs vinculadas (§12).
abstract interface class MemberAdminRepository {
  Stream<List<Member>> watchMembers();

  /// [AlreadyExistsFailure] si el usuario ya está ocupado.
  Future<Result<Member>> createMember({
    required String displayName,
    required String username,
    required String password,
    required String colorHex,
    required String avatar,
  });

  /// Nombre, color y avatar.
  Future<Result<void>> updateMember(Member member);

  /// Desactivar también cierra su sesión en la TV.
  Future<Result<void>> setMemberActive(Member member, {required bool active});

  /// Crea una cuenta nueva con el mismo usuario y la enlaza al integrante
  /// (§12.4). Antes hay que borrar la cuenta vieja en la consola de Firebase.
  Future<Result<void>> restoreAccess(
    Member member, {
    required String newPassword,
  });

  Stream<List<TvSession>> watchTvSessions();
  Future<Result<void>> unlinkTv(String tvUid);
}

/// Sesión de Firebase Auth.
abstract interface class AuthRepository {
  /// UID de la sesión actual, o `null` sin sesión.
  Stream<String?> uidChanges();
  String? get currentUid;
  Future<Result<void>> signInWithEmail(String email, String password);

  /// Pide la contraseña actual (Firebase exige una sesión reciente).
  Future<Result<void>> changePassword(String current, String next);
  Future<void> signOut();
}

/// La cuenta y el integrante de la sesión actual (User App).
abstract interface class MemberRepository {
  /// `null` si el admin no registró esa cuenta.
  Stream<Account?> watchAccount(String authUid);

  /// `null` si no existe.
  Stream<Member?> watchMember(String memberId);

  /// Para "Continuar" en el Home.
  Future<Result<void>> updateLastPlaylist(String memberId, String playlistId);
}

/// Progreso y avance de los videos de un integrante (§6.3, §8.6).
abstract interface class ProgressRepository {
  /// Progreso de todas las playlists del integrante, por id de playlist.
  Stream<Map<String, PlaylistProgress>> watchProgress(String memberId);

  Future<Result<void>> setCompleted({
    required String memberId,
    required String playlistId,
    required String videoId,
    required bool completed,
  });

  /// Guarda el segundo donde se quedó y lo marca como último video visto.
  Future<Result<void>> savePosition({
    required String memberId,
    required String playlistId,
    required String videoId,
    required Duration position,
  });

  /// Borra el avance (al terminar el video o con "Empezar de nuevo").
  Future<Result<void>> clearPosition({
    required String memberId,
    required String playlistId,
    required String videoId,
  });
}
