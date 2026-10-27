import 'package:ejercicios_app/app.dart';
import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/core/platform/device_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EjerciciosApp', () {
    testWidgets('muestra el flavor y el tipo de dispositivo', (tester) async {
      await tester.pumpWidget(
        const EjerciciosApp(
          flavor: AppFlavor.user,
          device: DeviceProfile(isTv: true),
        ),
      );

      expect(find.text('Ejercicios'), findsOneWidget);
      expect(find.text('Dispositivo: Google TV'), findsOneWidget);
    });

    testWidgets('el botón de prueba recibe el foco inicial (control remoto)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const EjerciciosApp(
          flavor: AppFlavor.admin,
          device: DeviceProfile(isTv: false),
        ),
      );
      await tester.pump();

      final focused = FocusManager.instance.primaryFocus?.context?.widget;
      expect(focused, isNotNull);
      expect(find.text('Probar video'), findsOneWidget);
    });
  });

  group('DeviceProfile.load', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(
      () => messenger.setMockMethodCallHandler(DeviceProfile.channel, null),
    );

    test('lee isTv del canal nativo', () async {
      messenger.setMockMethodCallHandler(
        DeviceProfile.channel,
        (call) async => true,
      );
      expect((await DeviceProfile.load()).isTv, isTrue);
    });

    test('si el canal falla, asume teléfono', () async {
      messenger.setMockMethodCallHandler(
        DeviceProfile.channel,
        (call) async => throw PlatformException(code: 'error'),
      );
      expect((await DeviceProfile.load()).isTv, isFalse);
    });
  });
}
