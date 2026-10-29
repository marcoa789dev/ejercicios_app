import 'dart:async';

import 'package:ejercicios_app/app.dart';
import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/core/data/firestore_catalog_repository.dart';
import 'package:ejercicios_app/core/data/firestore_member_repository.dart';
import 'package:ejercicios_app/core/data/firestore_progress_repository.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/platform/device_profile.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Sesión de Auth en memoria. `signInWithEmail` acepta [password] y entra
/// como [uid].
class FakeAuth implements AuthRepository {
  new({this.uid = 'u1', this.password = 'secreto1'});

  final String uid;
  final String password;
  final _uid = StreamController<String?>.broadcast();
  String? signedInEmail;

  /// Emite un cambio de sesión (como si Firebase lo notificara).
  void emit(String? uid) => _uid.add(uid);

  @override
  Stream<String?> uidChanges() => _uid.stream;

  @override
  String? get currentUid => null;

  @override
  Future<Result<void>> signInWithEmail(String email, String password) async {
    if (password != this.password) {
      return const Err(InvalidCredentialsFailure());
    }
    signedInEmail = email;
    emit(uid);
    return const Ok(null);
  }

  @override
  Future<Result<void>> changePassword(String current, String next) async =>
      current == password
      ? const Ok(null)
      : const Err(InvalidCredentialsFailure());

  @override
  Future<void> signOut() async => emit(null);
}

/// Reproductor simulado: no hay ExoPlayer en las pruebas.
class FakeVideoPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  Duration duration = const Duration(minutes: 5);

  /// Si es `true`, el siguiente video no carga (como sin internet).
  bool failNext = false;

  final calls = <String>[];
  final _events = <int, StreamController<VideoEvent>>{};
  final _positions = <int, Duration>{};
  final urls = <int, String>{};
  var _nextId = 0;

  /// Mueve la posición del reproductor actual (como si avanzara el video).
  void setPosition(Duration position) {
    for (final id in _events.keys) {
      _positions[id] = position;
    }
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    final fail = failNext;
    failNext = false;
    urls[id] = options.dataSource.uri ?? '';
    _positions[id] = Duration.zero;
    _events[id] = StreamController<VideoEvent>(
      onListen: () {
        if (fail) {
          _events[id]!.addError(
            PlatformException(code: 'VideoError', message: 'Source error'),
          );
        } else {
          _events[id]!.add(
            VideoEvent(
              eventType: VideoEventType.initialized,
              duration: duration,
              size: const Size(1920, 1080),
            ),
          );
        }
      },
    );
    calls.add('create ${urls[id]}');
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
    _events[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
    _events[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seek ${position.inSeconds}');
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      _positions[playerId] ?? Duration.zero;

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {
    calls.add('speed $speed');
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await _events.remove(playerId)?.close();
    _positions.remove(playerId);
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

class FakeWakelock extends WakelockPlusPlatformInterface {
  bool on = false;

  @override
  Future<void> toggle({required bool enable}) async => on = enable;

  @override
  Future<bool> get enabled async => on;
}

/// Catálogo de ejemplo: Rodilla con una semana de 3 videos (día 1: a, b;
/// día 2: c) y Hombro sin semanas. Integrante "Mamá" con cuenta activa.
Future<void> seedFamily(FakeFirebaseFirestore db) async {
  await db.collection('categories').doc('rodilla').set({
    'name': 'Rodilla',
    'order': 1,
    'is_active': true,
  });
  await db.collection('categories').doc('hombro').set({
    'name': 'Hombro',
    'order': 2,
    'is_active': true,
  });
  await db.collection('playlists').doc('rodilla-s1').set({
    'category_id': 'rodilla',
    'title': 'Semana de la rodilla',
    'goal': 'Fortalecer sin dolor',
    'level': 'beginner',
    'week_number': 1,
    'order': 1,
    'is_active': true,
    'total_videos': 3,
    'total_duration_seconds': 900,
    'days_count': 2,
  });
  for (final (id, day, order, title) in [
    ('a', 1, 1, 'Calentamiento suave'),
    ('b', 1, 2, 'Sentadilla a la silla con un título muy largo para ver'),
    ('c', 2, 1, 'Puente de glúteo'),
  ]) {
    await db.collection('videos').doc(id).set({
      'playlist_id': 'rodilla-s1',
      'category_id': 'rodilla',
      'title': title,
      'instructions': 'Respira profundo y no aguantes el aire.',
      'sets': 3,
      'reps': 10,
      'day_number': day,
      'order': order,
      'video_source': 'r2',
      'stream_url': 'https://x.r2.dev/$id.mp4',
      'duration_seconds': 300,
      'is_active': true,
    });
  }
  await db.collection('members').doc('m1').set({
    'display_name': 'Mamá',
    'username': 'mama',
    'color_hex': '#7E57C2',
    'avatar': 'flower',
    'order': 1,
    'is_active': true,
    'auth_uid': 'u1',
  });
  await db.collection('accounts').doc('u1').set({
    'member_id': 'm1',
    'username': 'mama',
    'is_active': true,
  });
}

/// Lo que la User App necesita, con Firestore falso y plataformas
/// simuladas. Usar `await env.dispose()` al terminar.
class TestEnv {
  new() {
    VideoPlayerPlatform.instance = video;
    wakelockPlusPlatformInstance = wakelock;
    PackageInfo.setMockInitialValues(
      appName: 'Ejercicios',
      packageName: 'com.ejerciciosapp.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    GetIt.I
      ..registerSingleton<AuthRepository>(auth)
      ..registerSingleton<MemberRepository>(FirestoreMemberRepository(db))
      ..registerSingleton<CatalogRepository>(FirestoreCatalogRepository(db))
      ..registerSingleton<ProgressRepository>(FirestoreProgressRepository(db));
  }

  final db = FakeFirebaseFirestore();
  final auth = FakeAuth();
  final video = FakeVideoPlatform();
  final wakelock = FakeWakelock();

  Future<void> dispose() => GetIt.I.reset();

  /// Abre la app con [uid] (null = sin sesión) y espera a que se acomode.
  Future<void> pumpApp(
    WidgetTester tester, {
    String? uid = 'u1',
    bool isTv = false,
  }) async {
    await tester.pumpWidget(
      EjerciciosApp(
        flavor: AppFlavor.user,
        device: DeviceProfile(isTv: isTv),
      ),
    );
    auth.emit(uid);
    await settle(tester);
  }
}

/// Como `pumpAndSettle`, pero con tope: el reproductor tiene temporizadores
/// periódicos que nunca "terminan".
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Cierra la app para que no queden temporizadores pendientes.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester, frames: 5);
}
