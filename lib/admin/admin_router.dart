import 'package:ejercicios_app/admin/auth/admin_session.dart';
import 'package:ejercicios_app/admin/auth/login_page.dart';
import 'package:ejercicios_app/admin/catalog/categories_page.dart';
import 'package:ejercicios_app/admin/catalog/category_form_page.dart';
import 'package:ejercicios_app/admin/catalog/playlist_form_page.dart';
import 'package:ejercicios_app/admin/catalog/playlists_page.dart';
import 'package:ejercicios_app/admin/catalog/video_form_page.dart';
import 'package:ejercicios_app/admin/catalog/videos_page.dart';
import 'package:ejercicios_app/admin/members/member_detail_page.dart';
import 'package:ejercicios_app/admin/members/member_new_page.dart';
import 'package:ejercicios_app/admin/members/members_page.dart';
import 'package:ejercicios_app/core/auth/login_cubit.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Rutas de la Admin App (§9.1). Las pantallas de edición reciben la
/// entidad por `extra`; si falta (no debería pasar), vuelven al inicio.
abstract final class AdminRoutes {
  static const login = '/login';
  static const denied = '/sin-permisos';
  static const categories = '/';
  static const categoryForm = '/categoria';
  static const playlists = '/playlists';
  static const playlistForm = '/playlist';
  static const videos = '/videos';
  static const videoForm = '/video';
  static const members = '/integrantes';
  static const memberNew = '/integrantes/nuevo';
  static const member = '/integrante';
}

/// Argumentos de [PlaylistFormPage]: sin playlist = nueva.
typedef PlaylistFormArgs = ({Category category, Playlist? playlist});

/// Argumentos de [VideoFormPage]: sin video = nuevo en `day`.
typedef VideoFormArgs = ({Playlist playlist, Video? video, int day});

GoRouter buildAdminRouter(AdminSession session) {
  String? requires<T>(GoRouterState s) =>
      s.extra is T ? null : AdminRoutes.categories;

  return GoRouter(
    refreshListenable: session,
    redirect: (context, state) {
      final at = state.matchedLocation;
      return switch (session.access) {
        AdminAccess.signedOut =>
          at == AdminRoutes.login ? null : AdminRoutes.login,
        AdminAccess.denied =>
          at == AdminRoutes.denied ? null : AdminRoutes.denied,
        AdminAccess.admin =>
          at == AdminRoutes.login || at == AdminRoutes.denied
              ? AdminRoutes.categories
              : null,
      };
    },
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        builder: (_, _) => BlocProvider(
          create: (_) => LoginCubit(GetIt.I()),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AdminRoutes.denied,
        builder: (_, _) => NoPermissionPage(session: session),
      ),
      GoRoute(
        path: AdminRoutes.categories,
        builder: (_, _) => CategoriesPage(onSignOut: session.signOut),
      ),
      GoRoute(
        path: AdminRoutes.categoryForm,
        builder: (_, s) => CategoryFormPage(category: s.extra as Category?),
      ),
      GoRoute(
        path: AdminRoutes.playlists,
        redirect: (_, s) => requires<Category>(s),
        builder: (_, s) => PlaylistsPage(category: s.extra! as Category),
      ),
      GoRoute(
        path: AdminRoutes.playlistForm,
        redirect: (_, s) => requires<PlaylistFormArgs>(s),
        builder: (_, s) {
          final args = s.extra! as PlaylistFormArgs;
          return PlaylistFormPage(
            category: args.category,
            playlist: args.playlist,
          );
        },
      ),
      GoRoute(
        path: AdminRoutes.videos,
        redirect: (_, s) => requires<Playlist>(s),
        builder: (_, s) => VideosPage(playlist: s.extra! as Playlist),
      ),
      GoRoute(
        path: AdminRoutes.videoForm,
        redirect: (_, s) => requires<VideoFormArgs>(s),
        builder: (_, s) {
          final args = s.extra! as VideoFormArgs;
          return VideoFormPage(
            playlist: args.playlist,
            video: args.video,
            initialDay: args.day,
          );
        },
      ),
      GoRoute(
        path: AdminRoutes.members,
        builder: (_, _) => const MembersPage(),
      ),
      GoRoute(
        path: AdminRoutes.memberNew,
        builder: (_, _) => const MemberNewPage(),
      ),
      GoRoute(
        path: AdminRoutes.member,
        redirect: (_, s) => requires<Member>(s),
        builder: (_, s) => MemberDetailPage(member: s.extra! as Member),
      ),
    ],
  );
}
