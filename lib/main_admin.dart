import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/bootstrap.dart';
import 'package:ejercicios_app/firebase_options_admin.dart';

Future<void> main() =>
    bootstrap(AppFlavor.admin, DefaultFirebaseOptions.currentPlatform);
