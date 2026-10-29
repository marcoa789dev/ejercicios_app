import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// Cada pantalla en los equipos de la casa, con texto normal y grande.
/// Un desbordamiento ("RenderFlex overflowed", las franjas amarillas y
/// negras) hace fallar la prueba.
void main() {
  // Tamaños lógicos (dp) y densidad aproximados
  const devices = <String, (Size, double)>{
    'teléfono chico (360×640)': (Size(360, 640), 2),
    'POCO / Xiaomi (393×873)': (Size(393, 873), 2.75),
    'Huawei (360×780)': (Size(360, 780), 3),
    'Pixel (412×915)': (Size(412, 915), 2.625),
    'teléfono acostado (873×393)': (Size(873, 393), 2.75),
    'Google TV 1080p (960×540)': (Size(960, 540), 2),
  };

  for (final MapEntry(key: name, value: (size, dpr)) in devices.entries) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets('$name · texto ×$textScale', (tester) async {
        tester.view
          ..physicalSize = size * dpr
          ..devicePixelRatio = dpr;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final env = TestEnv();
        addTearDown(env.dispose);
        await seedFamily(env.db);

        // Login
        await env.pumpApp(tester, uid: null, isTv: name.contains('TV'));
        expect(find.text('Entrar'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, 'mama');
        await tester.enterText(find.byType(TextFormField).last, 'secreto1');
        await tester.tap(find.text('Entrar'));
        await settle(tester);

        // Home → semana → reproductor → ajustes
        expect(find.text('Hola, Mamá'), findsOneWidget);
        final card = find.text('Semana de la rodilla');
        await tester.scrollUntilVisible(
          card,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(card);
        await settle(tester, frames: 3);
        await tester.tap(card);
        await settle(tester);

        final video = find.text('Calentamiento suave');
        await tester.scrollUntilVisible(
          video,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(video);
        await settle(tester, frames: 3);
        await tester.tap(video);
        await settle(tester);
        if (size.width < size.height) {
          expect(find.textContaining('Ejercicio 1 de 2'), findsOneWidget);
          expect(find.text('Siguiente ejercicio'), findsOneWidget);
        } else {
          // Acostado: el video en pantalla completa
          expect(find.byTooltip('Salir de pantalla completa'), findsOneWidget);
        }

        // Botón "Atrás" del sistema (también existe sin barra superior)
        await tester.binding.handlePopRoute();
        await settle(tester);
        await tester.binding.handlePopRoute();
        await settle(tester);
        await tester.tap(find.byTooltip('Ajustes'));
        await settle(tester);
        expect(find.text('Cambiar mi contraseña'), findsOneWidget);

        await closeApp(tester);
      });
    }
  }
}
