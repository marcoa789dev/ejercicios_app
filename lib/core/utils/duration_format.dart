/// `1:05:09` o `05:09`, para la duración de un video.
String formatClock(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// `7 h 05 min` o `45 min`, para totales.
String formatTotal(Duration d) {
  final minutes = d.inMinutes.remainder(60);
  if (d.inHours == 0) return '$minutes min';
  return '${d.inHours} h ${minutes.toString().padLeft(2, '0')} min';
}
