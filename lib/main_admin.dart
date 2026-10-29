import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ejercicios_app/admin/admin_app.dart';
import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/bootstrap.dart';
import 'package:ejercicios_app/core/data/firebase_auth_repository.dart';
import 'package:ejercicios_app/core/data/firestore_catalog_admin_repository.dart';
import 'package:ejercicios_app/core/data/firestore_member_admin_repository.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/firebase_options_admin.dart';

Future<void> main() {
  final options = DefaultFirebaseOptions.currentPlatform;
  return bootstrap(
    AppFlavor.admin,
    options,
    register: (di) {
      final db = FirebaseFirestore.instance;
      di
        ..registerSingleton<CatalogAdminRepository>(
          FirestoreCatalogAdminRepository(db),
        )
        ..registerSingleton<MemberAdminRepository>(
          FirestoreMemberAdminRepository(db, FirebaseAccountCreator(options)),
        );
    },
    buildApp: (_) => const AdminApp(),
  );
}
