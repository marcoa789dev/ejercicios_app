import 'package:ejercicios_app/admin/widgets/pending_page.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:flutter/material.dart';

/// Pendiente (Sprint 2): editar, desactivar y restablecer acceso.
class MemberDetailPage extends StatelessWidget {
  const new({required this.member, super.key});

  final Member member;

  @override
  Widget build(BuildContext context) => PendingPage(title: member.displayName);
}
