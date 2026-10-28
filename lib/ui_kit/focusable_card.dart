import 'package:flutter/material.dart';

/// Tarjeta que se activa con toque y con el control remoto (OK/Enter).
///
/// Con foco se agranda un 8 % y muestra un borde de 3 px del color primario,
/// visible a 3 m de distancia en la TV (PLAN_MAESTRO §11.3).
class FocusableCard extends StatefulWidget {
  const new({
    required this.child,
    required this.onPressed,
    this.autofocus = false,
    this.borderRadius = 16,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool autofocus;
  final double borderRadius;
  final String? semanticLabel;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  static const _duration = Duration(milliseconds: 150);
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.borderRadius);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _focused ? 1.08 : 1,
        duration: _duration,
        child: AnimatedContainer(
          duration: _duration,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _focused ? scheme.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: scheme.primary.withAlpha(90),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              autofocus: widget.autofocus,
              onTap: widget.onPressed,
              onFocusChange: (f) {
                setState(() => _focused = f);
                if (f) {
                  Scrollable.ensureVisible(
                    context,
                    alignment: 0.5,
                    duration: _duration,
                  );
                }
              },
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
