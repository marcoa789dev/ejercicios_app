import 'package:ejercicios_app/ui_kit/state_views.dart';
import 'package:flutter/material.dart';

/// Pantalla provisional de lo que falta del Sprint 2 (Admin App en pausa
/// mientras se hace la User App).
class PendingPage extends StatelessWidget {
  const new({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const EmptyView(
      icon: Icons.construction_rounded,
      message: 'Pendiente: se termina en el Sprint 2.',
    ),
  );
}
