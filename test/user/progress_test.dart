import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:ejercicios_app/user/next_up.dart';
import 'package:ejercicios_app/user/player/progress_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registra las llamadas como texto: "save 10", "clear", "done true".
class RecordingProgress implements ProgressRepository {
  final calls = <String>[];

  @override
  Stream<Map<String, PlaylistProgress>> watchProgress(String memberId) =>
      const Stream.empty();

  @override
  Future<Result<void>> savePosition({
    required String memberId,
    required String playlistId,
    required String videoId,
    required Duration position,
  }) async {
    calls.add('save ${position.inSeconds}');
    return const Ok(null);
  }

  @override
  Future<Result<void>> clearPosition({
    required String memberId,
    required String playlistId,
    required String videoId,
  }) async {
    calls.add('clear');
    return const Ok(null);
  }

  @override
  Future<Result<void>> setCompleted({
    required String memberId,
    required String playlistId,
    required String videoId,
    required bool completed,
  }) async {
    calls.add('done $completed');
    return const Ok(null);
  }
}

Video _video(String id, {int day = 1, int order = 1}) => Video(
  id: id,
  playlistId: 'p',
  categoryId: 'c',
  title: id,
  dayNumber: day,
  order: order,
  streamUrl: 'https://x.r2.dev/$id.mp4',
  durationSeconds: 100,
);

void main() {
  group('ProgressTracker (§8.6)', () {
    late RecordingProgress repo;
    late ProgressTracker tracker;

    setUp(() {
      repo = RecordingProgress();
      tracker = ProgressTracker(
        repo: repo,
        memberId: 'm',
        playlistId: 'p',
        videoId: 'v',
        duration: const Duration(seconds: 100),
      );
    });

    Future<void> tick(int from, int to) async {
      for (var s = from; s <= to; s++) {
        await tracker.onTick(Duration(seconds: s));
      }
    }

    test('mientras reproduce guarda cada 10 s', () async {
      await tick(0, 35);
      expect(repo.calls, ['save 10', 'save 20', 'save 30']);
    });

    test('al pausar guarda la posición exacta', () async {
      await tick(0, 14);
      await tracker.flush(const Duration(seconds: 14));
      expect(repo.calls, ['save 10', 'save 14']);
    });

    test('no repite si la posición no cambió', () async {
      await tracker.flush(const Duration(seconds: 42));
      await tracker.flush(const Duration(seconds: 42));
      expect(repo.calls, ['save 42']);
    });

    test('no guarda por debajo de 5 s', () async {
      await tracker.flush(const Duration(seconds: 3));
      expect(repo.calls, isEmpty);
    });

    test('al 90 % lo marca completado y al 95 % borra el avance', () async {
      await tick(85, 99);
      expect(repo.calls, ['save 85', 'done true', 'clear']);
      await tracker.flush(const Duration(seconds: 99));
      expect(repo.calls.last, 'clear', reason: 'terminado: no se guarda');
    });

    test('si regresa antes del 95 % vuelve a guardar', () async {
      await tick(95, 96);
      await tracker.flush(const Duration(seconds: 40));
      expect(repo.calls.last, 'save 40');
    });

    test('un video ya completado no se vuelve a marcar', () async {
      final done = ProgressTracker(
        repo: repo,
        memberId: 'm',
        playlistId: 'p',
        videoId: 'v',
        duration: const Duration(seconds: 100),
        alreadyCompleted: true,
      );
      await done.onTick(const Duration(seconds: 91));
      expect(repo.calls, isNot(contains('done true')));
    });

    test('"Empezar de nuevo" borra el avance', () async {
      await tracker.flush(const Duration(seconds: 50));
      await tracker.restart();
      expect(repo.calls, ['save 50', 'clear']);
    });
  });

  group('nextUp', () {
    final videos = [_video('a'), _video('b', order: 2), _video('c', day: 2)];

    test('sin progreso empieza por el primero', () {
      final n = nextUp(videos, null)!;
      expect(n.index, 0);
      expect(n.isResume, isFalse);
    });

    test('el último video a medias gana', () {
      final n = nextUp(
        videos,
        const PlaylistProgress(
          playlistId: 'p',
          completedVideoIds: {'a'},
          positionsSeconds: {'c': 40},
          lastVideoId: 'c',
        ),
      )!;
      expect(n.index, 2);
      expect(n.resumeAt, const Duration(seconds: 40));
    });

    test('si el último ya se completó, el primero pendiente', () {
      final n = nextUp(
        videos,
        const PlaylistProgress(
          playlistId: 'p',
          completedVideoIds: {'a', 'c'},
          lastVideoId: 'c',
        ),
      )!;
      expect(n.index, 1);
    });

    test('todo completado → null', () {
      expect(
        nextUp(
          videos,
          const PlaylistProgress(
            playlistId: 'p',
            completedVideoIds: {'a', 'b', 'c'},
          ),
        ),
        isNull,
      );
    });
  });

  test('cardFraction no pasa del 100 %', () {
    const p = Playlist(
      id: 'p',
      categoryId: 'c',
      title: 'S1',
      order: 1,
      totalVideos: 2,
    );
    expect(
      cardFraction(
        p,
        const PlaylistProgress(
          playlistId: 'p',
          completedVideoIds: {'a', 'b', 'borrado'},
        ),
      ),
      1,
    );
    expect(cardFraction(p, null), 0);
  });
}
