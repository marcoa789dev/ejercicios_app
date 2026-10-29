import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// Recorridos completos de la User App con Firestore falso y un reproductor
/// simulado. Cada prueba arranca la app entera, como en el teléfono.
void main() {
  /// Como 	estWidgets, en un teléfono parado (POCO/Xiaomi: 393×873 dp).
  void testFlow(String name, WidgetTesterCallback body) =>
      testWidgets(name, (tester) async {
        tester.view
          ..physicalSize = const Size(393, 873) * 2.75
          ..devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        await body(tester);
      });

  late TestEnv env;

  setUp(() async {
    env = TestEnv();
    await seedFamily(env.db);
  });

  tearDown(() => env.dispose());

  Future<Map<String, dynamic>> progress() async =>
      (await env.db
              .collection('members')
              .doc('m1')
              .collection('progress')
              .doc('rodilla-s1')
              .get())
          .data() ??
      const {};

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> openPlayer(WidgetTester tester, String videoTitle) async {
    await env.pumpApp(tester);
    await tapText(tester, 'Semana de la rodilla');
    await tapText(tester, videoTitle);
  }

  int creates() => env.video.calls.where((c) => c.startsWith('create')).length;

  group('Entrar', () {
    testFlow('con usuario y contraseña llega al Home', (tester) async {
      await env.pumpApp(tester, uid: null);
      await tester.enterText(find.byType(TextFormField).first, 'mama');
      await tester.enterText(find.byType(TextFormField).last, 'secreto1');
      await tester.tap(find.text('Entrar'));
      await settle(tester);

      expect(env.auth.signedInEmail, 'mama@ejercicios.local');
      expect(find.text('Hola, Mamá'), findsOneWidget);
      expect(find.text('Semana de la rodilla'), findsOneWidget);
      expect(find.text('0 %'), findsOneWidget);
      await closeApp(tester);
    });

    testFlow('contraseña incorrecta avisa sin tronar', (tester) async {
      await env.pumpApp(tester, uid: null);
      await tester.enterText(find.byType(TextFormField).first, 'mama');
      await tester.enterText(find.byType(TextFormField).last, 'otra-cosa');
      await tester.tap(find.text('Entrar'));
      await settle(tester);

      expect(
        find.text('El usuario o la contraseña no son correctos.'),
        findsOneWidget,
      );
      await closeApp(tester);
    });

    testFlow('cuenta desactivada no entra', (tester) async {
      await env.db.collection('accounts').doc('u1').update({
        'is_active': false,
      });
      await env.pumpApp(tester);
      expect(find.text('Tu acceso está desactivado'), findsOneWidget);
      await closeApp(tester);
    });

    testFlow('si el admin lo desactiva mientras ve un video, sale', (
      tester,
    ) async {
      await openPlayer(tester, 'Calentamiento suave');
      await env.db.collection('accounts').doc('u1').update({
        'is_active': false,
      });
      await settle(tester);
      expect(find.text('Tu acceso está desactivado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeApp(tester);
    });
  });

  group('Home', () {
    testFlow('categoría sin semanas muestra un aviso', (tester) async {
      await env.pumpApp(tester);
      await tapText(tester, 'Hombro');
      expect(
        find.text('Esta categoría todavía no tiene semanas.'),
        findsOneWidget,
      );
      await closeApp(tester);
    });

    testFlow('sin catálogo muestra un aviso', (tester) async {
      for (final id in ['rodilla', 'hombro']) {
        await env.db.collection('categories').doc(id).delete();
      }
      await env.pumpApp(tester);
      expect(find.textContaining('Todavía no hay rutinas'), findsOneWidget);
      await closeApp(tester);
    });

    testFlow('"Continuar" lleva al video a medias', (tester) async {
      await env.db
          .collection('members')
          .doc('m1')
          .collection('progress')
          .doc('rodilla-s1')
          .set({
            'playlist_id': 'rodilla-s1',
            'positions': {'c': 90},
            'last_video_id': 'c',
          });
      await env.pumpApp(tester);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.textContaining('01:30 de 05:00'), findsOneWidget);

      await tapText(tester, 'Puente de glúteo');
      expect(env.video.calls, contains('create https://x.r2.dev/c.mp4'));
      expect(env.video.calls, contains('seek 87'));
      await closeApp(tester);
    });
  });

  group('Reproductor', () {
    testFlow(
      'abrir un video no lo reconstruye (error "Null check" del 29/10)',
      (tester) async {
        await openPlayer(tester, 'Calentamiento suave');
        await settle(tester, frames: 30);

        expect(tester.takeException(), isNull);
        // Guardó la última semana (lo que antes tumbaba el reproductor)…
        final member = await env.db.collection('members').doc('m1').get();
        expect(member['last_playlist_id'], 'rodilla-s1');
        // …y el reproductor siguió siendo el mismo
        expect(creates(), 1);
        expect(env.video.calls, isNot(contains('dispose')));
        expect(find.text('Día 1 · Ejercicio 1 de 2'), findsOneWidget);
        expect(env.wakelock.on, isTrue, reason: 'pantalla encendida');
        await closeApp(tester);
        expect(env.wakelock.on, isFalse);
      },
    );

    testFlow('reanuda 3 s antes y "Empezar de nuevo" borra', (tester) async {
      await env.db
          .collection('members')
          .doc('m1')
          .collection('progress')
          .doc('rodilla-s1')
          .set({
            'playlist_id': 'rodilla-s1',
            'positions': {'a': 151},
            'last_video_id': 'a',
          });
      await openPlayer(tester, 'Calentamiento suave');

      expect(env.video.calls, contains('seek 148'));
      expect(find.text('Continuando desde 02:28'), findsOneWidget);

      await tester.tap(find.text('Empezar de nuevo'));
      await settle(tester);
      expect(env.video.calls.last, 'seek 0');
      expect((await progress())['positions'], isEmpty);
      await closeApp(tester);
    });

    testFlow('un video ya completado empieza desde 0', (tester) async {
      await env.db
          .collection('members')
          .doc('m1')
          .collection('progress')
          .doc('rodilla-s1')
          .set({
            'playlist_id': 'rodilla-s1',
            'completed_video_ids': ['a'],
            'positions': {'a': 100},
          });
      await openPlayer(tester, 'Calentamiento suave');
      expect(env.video.calls.where((c) => c.startsWith('seek')), isEmpty);
      await closeApp(tester);
    });

    testFlow('guarda el avance al salir', (tester) async {
      await openPlayer(tester, 'Calentamiento suave');
      env.video.setPosition(const Duration(seconds: 47));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);

      expect((await progress())['positions'], {'a': 47});
      expect(find.text('Semana de la rodilla'), findsWidgets);
      await closeApp(tester);
    });

    testFlow('guarda el avance si la app pasa a segundo plano', (tester) async {
      await openPlayer(tester, 'Calentamiento suave');
      env.video.setPosition(const Duration(seconds: 33));
      await settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await settle(tester);

      expect((await progress())['positions'], {'a': 33});
      expect(env.video.calls.last, 'pause');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await closeApp(tester);
    });

    testFlow('al 90 % se marca completado solo', (tester) async {
      await openPlayer(tester, 'Calentamiento suave');
      env.video.setPosition(const Duration(seconds: 271));
      await settle(tester);

      expect((await progress())['completed_video_ids'], ['a']);
      expect(find.text('Completado'), findsOneWidget);
      await closeApp(tester);
    });

    testFlow('marcar y desmarcar a mano', (tester) async {
      await openPlayer(tester, 'Calentamiento suave');
      await tapText(tester, 'Marcar como completado');
      expect((await progress())['completed_video_ids'], ['a']);
      await tapText(tester, 'Completado');
      expect((await progress())['completed_video_ids'], isEmpty);
      await closeApp(tester);
    });

    testFlow('siguiente ejercicio pasa al día siguiente', (tester) async {
      await openPlayer(
        tester,
        'Sentadilla a la silla con un título muy '
        'largo para ver',
      );
      await tapText(tester, 'Siguiente ejercicio');

      expect(env.video.calls, contains('create https://x.r2.dev/c.mp4'));
      expect(find.text('Día 2 · Ejercicio 1 de 1'), findsOneWidget);
      expect(find.text('Terminar la semana'), findsOneWidget);
      await closeApp(tester);
    });

    testFlow('al terminar la semana felicita y regresa', (tester) async {
      await openPlayer(tester, 'Puente de glúteo');
      await tapText(tester, 'Terminar la semana');
      expect(find.text('¡Terminaste la semana!'), findsOneWidget);

      await tapText(tester, 'Volver');
      expect(find.text('Semana de la rodilla'), findsWidgets);
      expect(tester.takeException(), isNull);
      await closeApp(tester);
    });

    testFlow('sin internet muestra "Reintentar" y luego reproduce', (
      tester,
    ) async {
      env.video.failNext = true;
      await openPlayer(tester, 'Calentamiento suave');
      expect(find.textContaining('No se pudo cargar el video'), findsOneWidget);

      await tapText(tester, 'Reintentar');
      expect(creates(), 2);
      expect(env.video.calls, contains('play'));
      expect(find.textContaining('No se pudo cargar'), findsNothing);
      await closeApp(tester);
    });
  });
}
