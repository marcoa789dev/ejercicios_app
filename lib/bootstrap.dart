import 'dart:async';

import 'package:ejercicios_app/app.dart';
import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/core/platform/device_profile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

/// Arranque común de los dos flavors.
///
/// Cada `main_*.dart` pasa las opciones de Firebase de su propia app
/// (`firebase_options_user.dart` / `firebase_options_admin.dart`).
Future<void> bootstrap(
  AppFlavor flavor,
  FirebaseOptions firebaseOptions,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: firebaseOptions);

  // En debug los errores se ven en consola; en release se envían a Crashlytics.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(crashlytics.recordError(error, stack, fatal: true));
    return true;
  };

  final device = await DeviceProfile.load();
  await crashlytics.setCustomKey('flavor', flavor.name);
  await crashlytics.setCustomKey('is_tv', device.isTv);

  GetIt.I
    ..registerSingleton<AppFlavor>(flavor)
    ..registerSingleton<DeviceProfile>(device);

  runApp(EjerciciosApp(flavor: flavor, device: device));
}
