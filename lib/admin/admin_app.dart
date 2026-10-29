import 'package:ejercicios_app/admin/admin_router.dart';
import 'package:ejercicios_app/admin/auth/admin_session.dart';
import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/ui_kit/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Admin App (solo teléfono, §9).
class AdminApp extends StatefulWidget {
  const new({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AdminSession _session = AdminSession(GetIt.I());
  late final GoRouter _router = buildAdminRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppFlavor.admin.title,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    routerConfig: _router,
  );
}
