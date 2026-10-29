import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/app.dart';
import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/bootstrap.dart';
import 'package:ejercicios_app/core/data/firestore_member_repository.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/firebase_options_user.dart';

Future<void> main() => bootstrap(
  AppFlavor.user,
  DefaultFirebaseOptions.currentPlatform,
  register: (di) => di.registerSingleton<MemberRepository>(
    FirestoreMemberRepository(FirebaseFirestore.instance),
  ),
  buildApp: (device) => EjerciciosApp(flavor: AppFlavor.user, device: device),
);
