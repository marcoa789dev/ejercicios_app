/// Qué APK se está ejecutando.
///
/// Se elige con `--flavor` y el archivo `-t lib/main_*.dart`.
enum AppFlavor {
  user('Ejercicios'),
  admin('Ejercicios Admin');

  new(this.title);

  final String title;
}
