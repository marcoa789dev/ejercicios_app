import 'package:ejercicios_app/ui_kit/focusable_card.dart';
import 'package:ejercicios_app/ui_kit/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  shortcuts: {
    ...WidgetsApp.defaultShortcuts,
    const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
  },
  home: Scaffold(body: child),
);

void main() {
  testWidgets('ErrorView: Reintentar tiene el foco y responde a OK', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _wrap(ErrorView(message: 'Sin conexión', onRetry: () => retries++)),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('FocusableCard: ← / → mueven el foco y OK la activa', (
    tester,
  ) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      _wrap(
        Row(
          children: [
            for (final id in ['a', 'b'])
              Padding(
                padding: const EdgeInsets.all(16),
                child: FocusableCard(
                  autofocus: id == 'a',
                  onPressed: () => pressed.add(id),
                  child: SizedBox(width: 100, height: 60, child: Text(id)),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(pressed, ['a', 'b']);
  });

  testWidgets('EmptyView muestra el mensaje y la acción', (tester) async {
    var created = false;
    await tester.pumpWidget(
      _wrap(
        EmptyView(
          message: 'Aún no hay categorías',
          actionLabel: 'Crear la primera',
          onAction: () => created = true,
        ),
      ),
    );
    await tester.tap(find.text('Crear la primera'));
    expect(find.text('Aún no hay categorías'), findsOneWidget);
    expect(created, isTrue);
  });
}
