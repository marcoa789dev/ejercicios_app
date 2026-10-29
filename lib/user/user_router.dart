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
    // Solo cambios de acceso: si refrescara con cada cambio del integrante
    // (ej. last_playlist_id al abrir un video), reconstruiría el reproductor
    refreshListenable: session.accessListenable,
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
      // Sin su `extra` (no debería pasar) vuelven al Home en lugar de tronar
      GoRoute(
        path: UserRoutes.playlist,
        redirect: (_, s) => s.extra is Playlist ? null : UserRoutes.home,
        builder: (_, s) => switch (s.extra) {
          final Playlist playlist => withMember(
            (m) => PlaylistPage(member: m, playlist: playlist),
          ),
          _ => const _BackHome(),
        },
      ),
      GoRoute(
        path: UserRoutes.player,
        redirect: (_, s) => s.extra is PlayerArgs ? null : UserRoutes.home,
        builder: (_, s) => switch (s.extra) {
          final PlayerArgs args => withMember(
            (m) => PlayerPage(
              member: m,
              playlist: args.playlist,
              videos: args.videos,
              index: args.index,
            ),
          ),
          _ => const _BackHome(),
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

class _BackHome extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go(UserRoutes.home);
    });
    return const SplashPage();
  }
}
