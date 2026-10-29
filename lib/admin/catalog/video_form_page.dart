import 'package:ejercicios_app/admin/widgets/pending_page.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:flutter/material.dart';

/// Pendiente (Sprint 2): formulario de video con "Probar video".
class VideoFormPage extends StatelessWidget {
  const new({
    required this.playlist,
    required this.initialDay,
    this.video,
    super.key,
  });

  final Playlist playlist;
  final Video? video;
  final int initialDay;

  @override
  Widget build(BuildContext context) =>
      PendingPage(title: video == null ? 'Nuevo video' : 'Editar video');
}
