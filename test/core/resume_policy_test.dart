import 'package:ejercicios_app/core/domain/progress.dart';
import 'package:ejercicios_app/core/utils/resume_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hour = Duration(hours: 1);

  group('ResumePolicy.startAt', () {
    test('sin avance guardado empieza desde 0', () {
      expect(ResumePolicy.startAt(saved: null, duration: hour), Duration.zero);
    });

    test('menos de 5 s guardados cuenta como no empezado', () {
      expect(
        ResumePolicy.startAt(saved: const Duration(seconds: 4), duration: hour),
        Duration.zero,
      );
    });

    test('reanuda 3 s antes del punto guardado', () {
      expect(
        ResumePolicy.startAt(
          saved: const Duration(seconds: 151),
          duration: hour,
        ),
        const Duration(seconds: 148),
      );
    });

    test('a partir del 95 % se considera terminado y empieza desde 0', () {
      final at95 = Duration(milliseconds: (hour.inMilliseconds * 0.95).round());
      expect(ResumePolicy.startAt(saved: at95, duration: hour), Duration.zero);
      expect(
        ResumePolicy.startAt(
          saved: at95 - const Duration(seconds: 1),
          duration: hour,
        ),
        at95 - const Duration(seconds: 4),
      );
    });

    test('duración desconocida (0) empieza desde 0', () {
      expect(
        ResumePolicy.startAt(
          saved: const Duration(minutes: 5),
          duration: Duration.zero,
        ),
        Duration.zero,
      );
    });
  });

  test('isCompleted se activa al 90 %', () {
    expect(
      ResumePolicy.isCompleted(const Duration(minutes: 53), hour),
      isFalse,
    );
    expect(ResumePolicy.isCompleted(const Duration(minutes: 54), hour), isTrue);
  });

  group('PlaylistProgress', () {
    const p = PlaylistProgress(
      playlistId: 'p1',
      completedVideoIds: {'v1', 'v2', 'borrado'},
      positionsSeconds: {'v3': 151},
    );

    test('el % solo cuenta videos activos (nunca pasa del 100 %)', () {
      expect(p.fractionOf(['v1', 'v2', 'v3', 'v4']), 0.5);
      expect(p.fractionOf(['v1', 'v2']), 1.0);
      expect(p.fractionOf(const []), 0);
    });

    test('positionOf devuelve el avance guardado', () {
      expect(p.positionOf('v3'), const Duration(seconds: 151));
      expect(p.positionOf('v1'), isNull);
    });
  });
}
