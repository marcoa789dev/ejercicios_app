import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/core/platform/device_profile.dart';
import 'package:ejercicios_app/dev/sprint0_home_page.dart';
import 'package:ejercicios_app/ui_kit/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EjerciciosApp extends StatelessWidget {
  const new({required this.flavor, required this.device, super.key});

  final AppFlavor flavor;
  final DeviceProfile device;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: flavor.title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // En la TV siempre oscuro (§11.5 del plan)
      themeMode: device.isTv ? ThemeMode.dark : ThemeMode.system,
      // El botón OK/centro del control remoto debe activar el elemento enfocado
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
      },
      home: Sprint0HomePage(flavor: flavor, device: device),
    );
  }
}
