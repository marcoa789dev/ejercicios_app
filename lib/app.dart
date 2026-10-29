import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/core/platform/device_profile.dart';
import 'package:ejercicios_app/ui_kit/app_theme.dart';
import 'package:ejercicios_app/user/user_router.dart';
import 'package:ejercicios_app/user/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// User App (teléfono; la interfaz de TV llega en el Sprint 4).
class EjerciciosApp extends StatefulWidget {
  const new({required this.flavor, required this.device, super.key});

  final AppFlavor flavor;
  final DeviceProfile device;

  @override
  State<EjerciciosApp> createState() => _EjerciciosAppState();
}

class _EjerciciosAppState extends State<EjerciciosApp> {
  late final UserSession _session = UserSession(GetIt.I(), GetIt.I());
  late final GoRouter _router = buildUserRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: widget.flavor.title,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    // En la TV siempre oscuro (§11.5 del plan)
    themeMode: widget.device.isTv ? ThemeMode.dark : ThemeMode.system,
    // El botón OK/centro del control remoto debe activar el elemento enfocado
    shortcuts: {
      ...WidgetsApp.defaultShortcuts,
      const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
    },
    routerConfig: _router,
  );
}
