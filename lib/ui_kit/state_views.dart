import 'package:flutter/material.dart';

/// Error con botón "Reintentar" (enfocado al aparecer, para el control remoto).
class ErrorView extends StatelessWidget {
  const new({
    required this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _StateView(
    icon: icon,
    message: message,
    action: onRetry == null
        ? null
        : FilledButton.icon(
            autofocus: true,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
  );
}

/// Lista vacía, con una acción opcional (ej. "Crear la primera categoría").
class EmptyView extends StatelessWidget {
  const new({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _StateView(
    icon: icon,
    message: message,
    action: actionLabel == null
        ? null
        : FilledButton(onPressed: onAction, child: Text(actionLabel!)),
  );
}

class _StateView extends StatelessWidget {
  const new({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
