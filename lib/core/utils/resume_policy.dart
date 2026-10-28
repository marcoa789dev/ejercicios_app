/// Desde dónde reanudar un video (PLAN_MAESTRO §8.6).
abstract final class ResumePolicy {
  /// Por debajo de esto se considera "no empezado".
  static const minSaved = Duration(seconds: 5);

  /// Se retrocede un poco para retomar el movimiento del ejercicio.
  static const rewind = Duration(seconds: 3);

  /// A partir de esta fracción el video cuenta como terminado.
  static const finishedFraction = 0.95;

  /// Fracción a la que se marca el video como completado.
  static const completedFraction = 0.90;

  /// Posición inicial, o [Duration.zero] si debe empezar desde el principio.
  static Duration startAt({
    required Duration? saved,
    required Duration duration,
  }) {
    if (saved == null || duration <= Duration.zero) return Duration.zero;
    if (saved < minSaved || isFinished(saved, duration)) return Duration.zero;
    final start = saved - rewind;
    return start.isNegative ? Duration.zero : start;
  }

  static bool isFinished(Duration position, Duration duration) =>
      duration > Duration.zero &&
      position.inMilliseconds >= duration.inMilliseconds * finishedFraction;

  static bool isCompleted(Duration position, Duration duration) =>
      duration > Duration.zero &&
      position.inMilliseconds >= duration.inMilliseconds * completedFraction;
}
