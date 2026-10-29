import 'dart:async';

import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:ejercicios_app/core/utils/username.dart';
import 'package:ejercicios_app/ui_kit/feedback.dart';
import 'package:ejercicios_app/ui_kit/palette.dart';
import 'package:ejercicios_app/user/user_session.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Ajustes (§10.2): cambiar mi contraseña, cerrar sesión y versión.
/// Vincular la TV llega en el Sprint 4.
class SettingsPage extends StatelessWidget {
  const new({required this.member, required this.session, super.key});

  final Member member;
  final UserSession session;

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Cerrar sesión',
      message: 'Para volver a entrar necesitarás tu usuario y contraseña.',
      action: 'Cerrar sesión',
    );
    if (ok) await session.signOut();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajustes')),
    body: ListView(
      children: [
        ListTile(
          leading: MemberAvatar(
            colorHex: member.colorHex,
            avatar: member.avatar,
          ),
          title: Text(member.displayName),
          subtitle: Text('Usuario: ${member.username}'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.password_rounded),
          title: const Text('Cambiar mi contraseña'),
          onTap: () => unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => const _ChangePasswordDialog(),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout_rounded),
          title: const Text('Cerrar sesión'),
          onTap: () => unawaited(_signOut(context)),
        ),
        const Divider(),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) => ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Versión'),
            subtitle: Text(
              snap.data == null
                  ? '…'
                  : '${snap.data!.version} (${snap.data!.buildNumber})',
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const new();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await GetIt.I<AuthRepository>().changePassword(
      _current.text,
      _next.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Contraseña cambiada')));
      case Err(:final failure):
        setState(() {
          _saving = false;
          _error = failure is InvalidCredentialsFailure
              ? 'La contraseña actual no es correcta.'
              : failureMessage(failure);
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cambiar mi contraseña'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña actual'),
            validator: (v) => (v ?? '').isEmpty ? 'Escríbela' : null,
          ),
          TextFormField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña nueva'),
            validator: validatePassword,
          ),
          TextFormField(
            controller: _repeat,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Repite la nueva'),
            validator: (v) => v == _next.text ? null : 'No coinciden',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Guardando…' : 'Cambiar'),
      ),
    ],
  );
}
