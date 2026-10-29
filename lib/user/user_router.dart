import 'package:ejercicios_app/core/auth/login_cubit.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/user/auth/user_login_page.dart';
import 'package:ejercicios_app/user/home/home_page.dart';
import 'package:ejercicios_app/user/player/player_page.dart';
import 'package:ejercicios_app/user/playlist/playlist_page.dart';
import 'package:ejercicios_app/user/settings/settings_page.dart';
import 'package:ejercicios_app/user/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Rutas de la User App en el teléfono (§10.1).
abstract final class UserRoutes {
  static const loading = '/cargando';
  static const login = '/login';
  static const disabled = '/sin-acceso';
  static const home = '/';
  static const playlist = '/semana';
  static const player = '/reproducir';
  static const settings = '/ajustes';
}

/// Argumentos del reproductor: videos activos en orden y cuál empieza.
typedef PlayerArgs = ({Playlist playlist, List<Video> videos, int index});

GoRouter buildUserRouter(UserSession session) {
  // Las pantallas internas solo se construyen con un integrante listo
  Widget withMember(Widget Function(Member member) build) {
    final m = session.member;
    return m == null ? const SplashPage() : build(m);
  }

  return GoRouter(
    refreshListenable: session,
    initialLocation: UserRoutes.home,
    redirect: (context, state) {
      final at = state.matchedLocation;
      String? only(String path) => at == path ? null : path;
      return switch (session.access) {
        UserAccess.loading => only(UserRoutes.loading),
        UserAccess.signedOut => only(UserRoutes.login),
        UserAccess.disabled => only(UserRoutes.disabled),
        UserAccess.ready =>
          at == UserRoutes.loading ||
                  at == UserRoutes.login ||
                  at == UserRoutes.disabled
              ? UserRoutes.home
              : null,
      };
    },
    routes: [
      GoRoute(path: UserRoutes.loading, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: UserRoutes.login,
        builder: (_, _) => BlocProvider(
          create: (_) => LoginCubit(GetIt.I()),
          child: const UserLoginPage(),
        ),
      ),
      GoRoute(
        path: UserRoutes.disabled,
        builder: (_, _) => DisabledPage(session: session),
      ),
      GoRoute(
        path: UserRoutes.home,
        builder: (_, _) => withMember((m) => HomePage(member: m)),
      ),
      GoRoute(
        path: UserRoutes.playlist,
        redirect: (_, s) => s.extra is Playlist ? null : UserRoutes.home,
        builder: (_, s) => withMember(
          (m) => PlaylistPage(member: m, playlist: s.extra! as Playlist),
        ),
      ),
      GoRoute(
        path: UserRoutes.player,
        redirect: (_, s) => s.extra is PlayerArgs ? null : UserRoutes.home,
        builder: (_, s) {
          final args = s.extra! as PlayerArgs;
          return withMember(
            (m) => PlayerPage(
              member: m,
              playlist: args.playlist,
              videos: args.videos,
              index: args.index,
            ),
          );
        },
      ),
      GoRoute(
        path: UserRoutes.settings,
        builder: (_, _) =>
            withMember((m) => SettingsPage(member: m, session: session)),
      ),
    ],
  );
}
