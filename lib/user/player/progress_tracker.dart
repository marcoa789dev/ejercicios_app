import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/utils/resume_policy.dart';

/// Decide cuándo guardar el avance de un video (PLAN_MAESTRO §8.6).
///
/// - [onTick] mientras se reproduce: guarda cada 10 s de avance.
/// - [flush] al pausar, saltar, salir o pasar a segundo plano.
/// - Al 90 % marca el video como completado; al 95 % borra el avance
///   (ya no hay nada que reanudar) y deja de guardar.
///
/// Las escrituras no se esperan en la interfaz: sin conexión, Firestore las
/// encola y las sube al reconectar.
class ProgressTracker {
  new({
    required this.repo,
    required this.memberId,
    required this.playlistId,
    required this.videoId,
    required this.duration,
    bool alreadyCompleted = false,
  }) : _completed = alreadyCompleted;

  static const saveEvery = Duration(seconds: 10);

  final ProgressRepository repo;
  final String memberId;
  final String playlistId;
  final String videoId;
  final Duration duration;

  bool _completed;
  bool _finished = false;
  int? _lastSavedSeconds;

  bool get isCompleted => _completed;

  Future<void> onTick(Duration position) async {
    await _milestones(position);
    if (_finished) return;
    final last = _lastSavedSeconds ?? 0;
    if (position.inSeconds - last >= saveEvery.inSeconds) await _save(position);
  }

  Future<void> flush(Duration position) async {
    await _milestones(position);
    if (_finished || position < ResumePolicy.minSaved) return;
    if (position.inSeconds == _lastSavedSeconds) return;
    await _save(position);
  }

  /// "Empezar de nuevo": borra el avance guardado.
  Future<void> restart() async {
    _lastSavedSeconds = 0;
    _finished = false;
    await repo.clearPosition(
      memberId: memberId,
      playlistId: playlistId,
      videoId: videoId,
    );
  }

  /// Marcar o desmarcar a mano.
  Future<void> setCompleted({required bool completed}) async {
    _completed = completed;
    await repo.setCompleted(
      memberId: memberId,
      playlistId: playlistId,
      videoId: videoId,
      completed: completed,
    );
  }

  Future<void> _milestones(Duration position) async {
    if (!_completed && ResumePolicy.isCompleted(position, duration)) {
      await setCompleted(completed: true);
    }
    final finished = ResumePolicy.isFinished(position, duration);
    if (finished && !_finished) {
      _finished = true;
      await repo.clearPosition(
        memberId: memberId,
        playlistId: playlistId,
        videoId: videoId,
      );
    } else if (!finished) {
      // Si regresa antes del 95 %, se vuelve a guardar
      _finished = false;
    }
  }

  Future<void> _save(Duration position) async {
    _lastSavedSeconds = position.inSeconds;
    await repo.savePosition(
      memberId: memberId,
      playlistId: playlistId,
      videoId: videoId,
      position: position,
    );
  }
}
