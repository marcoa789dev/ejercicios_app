import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/core/platform/device_profile.dart';
import 'package:ejercicios_app/dev/video_smoke_test_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// URL del video de prueba en R2.
///
/// Se pasa al compilar para no dejarla en el código:
/// ```sh
/// flutter run --flavor user -t lib/main_user.dart \
///   --dart-define=TEST_VIDEO_URL=https://...
/// ```
const kTestVideoUrl = String.fromEnvironment('TEST_VIDEO_URL');

/// Pantalla provisional del Sprint 0.
///
/// Verifica el flavor, la detección de TV y la reproducción.
class Sprint0HomePage extends StatelessWidget {
  const new({required this.flavor, required this.device, super.key});

  final AppFlavor flavor;
  final DeviceProfile device;

  static String _firebaseStatus() => Firebase.apps.isEmpty
      ? 'no inicializado'
      : 'conectado a ${Firebase.app().options.projectId}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(flavor.title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Sprint 0 — prueba de entorno', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('Flavor: ${flavor.name}'),
          Text('Dispositivo: ${device.isTv ? 'Google TV' : 'Teléfono'}'),
          Text('Firebase: ${_firebaseStatus()}'),
          Text(
            kTestVideoUrl.isEmpty
                ? 'Video de prueba: sin URL '
                      '(usa --dart-define=TEST_VIDEO_URL=...)'
                : 'Video de prueba: $kTestVideoUrl',
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              autofocus: true,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Probar video'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VideoSmokeTestPage(url: kTestVideoUrl),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
