import 'dart:async';

import 'package:ejercicios_app/app.dart';
import 'package:ejercicios_app/app_flavor.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/platform/device_profile.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:ejercicios_app/user/user_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class FakeAuth implements AuthRepository {
  final uid = StreamController<String?>.broadcast();
  String? signedInEmail;

  @override
  Stream<String?> uidChanges() => uid.stream;

  @override
  String? get currentUid => null;

  @override
  Future<Result<void>> signInWithEmail(String email, String password) async {
    signedInEmail = email;
    return const Ok(null);
  }

  @override
  Future<Result<void>> changePassword(String current, String next) async =>
      const Ok(null);

  @override
  Future<void> signOut() async => uid.add(null);
}

class FakeMembers implements MemberRepository {
  final accounts = <String, StreamController<Account?>>{};
  final members = <String, StreamController<Member?>>{};

  StreamController<Account?> account(String uid) =>
      accounts[uid] ??= StreamController<Account?>.broadcast();
  StreamController<Member?> member(String id) =>
      members[id] ??= StreamController<Member?>.broadcast();

  @override
  Stream<Account?> watchAccount(String authUid) => account(authUid).stream;

  @override
  Stream<Member?> watchMember(String memberId) => member(memberId).stream;

  @override
  Future<Result<void>> updateLastPlaylist(String memberId, String id) async =>
      const Ok(null);
}

const _mama = Member(
  id: 'm1',
  displayName: 'Mamá',
  username: 'mama',
  order: 1,
  authUid: 'u1',
);

void main() {
  group('UserSession', () {
    late FakeAuth auth;
    late FakeMembers members;
    late UserSession session;

    setUp(() {
      auth = FakeAuth();
      members = FakeMembers();
      session = UserSession(auth, members);
    });

    tearDown(() => session.dispose());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('empieza cargando y sin sesión pasa a signedOut', () async {
      expect(session.access, UserAccess.loading);
      auth.uid.add(null);
      await settle();
      expect(session.access, UserAccess.signedOut);
    });

    test('cuenta no registrada → desactivado', () async {
      auth.uid.add('u1');
      await settle();
      members.account('u1').add(null);
      await settle();
      expect(session.access, UserAccess.disabled);
    });

    test('cuenta inactiva → desactivado', () async {
      auth.uid.add('u1');
      await settle();
      members
          .account('u1')
          .add(
            const Account(memberId: 'm1', username: 'mama', isActive: false),
          );
      await settle();
      expect(session.access, UserAccess.disabled);
    });

    test('cuenta e integrante activos → listo con el integrante', () async {
      auth.uid.add('u1');
      await settle();
      members
          .account('u1')
          .add(const Account(memberId: 'm1', username: 'mama', isActive: true));
      await settle();
      members.member('m1').add(_mama);
      await settle();
      expect(session.access, UserAccess.ready);
      expect(session.member?.displayName, 'Mamá');
    });

    test('si el admin lo desactiva mientras usa la app, reacciona', () async {
      auth.uid.add('u1');
      await settle();
      members
          .account('u1')
          .add(const Account(memberId: 'm1', username: 'mama', isActive: true));
      await settle();
      members.member('m1').add(_mama);
      await settle();
      members.member('m1').addError(Exception('permission-denied'));
      await settle();
      expect(session.access, UserAccess.disabled);
      expect(session.member, isNull);
    });
  });

  group('EjerciciosApp', () {
    late FakeAuth auth;

    setUp(() {
      auth = FakeAuth();
      GetIt.I
        ..registerSingleton<AuthRepository>(auth)
        ..registerSingleton<MemberRepository>(FakeMembers());
    });

    tearDown(() => GetIt.I.reset());

    testWidgets('sin sesión muestra el login con usuario y contraseña', (
      tester,
    ) async {
      await tester.pumpWidget(
        const EjerciciosApp(
          flavor: AppFlavor.user,
          device: DeviceProfile(isTv: false),
        ),
      );
      auth.uid.add(null);
      await tester.pumpAndSettle();

      expect(find.text('Usuario'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.textContaining('Olvidaste tu contraseña'), findsOneWidget);
    });

    testWidgets('el usuario se convierte en usuario@ejercicios.local', (
      tester,
    ) async {
      await tester.pumpWidget(
        const EjerciciosApp(
          flavor: AppFlavor.user,
          device: DeviceProfile(isTv: false),
        ),
      );
      auth.uid.add(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText).first, 'Mama');
      await tester.enterText(find.byType(EditableText).last, 'secreto1');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(auth.signedInEmail, isNull, reason: 'Mama no es válido');
      await tester.enterText(find.byType(EditableText).first, 'mama');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(auth.signedInEmail, 'mama@ejercicios.local');
    });
  });

  group('DeviceProfile.load', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(
      () => messenger.setMockMethodCallHandler(DeviceProfile.channel, null),
    );

    test('lee isTv del canal nativo', () async {
      messenger.setMockMethodCallHandler(
        DeviceProfile.channel,
        (call) async => true,
      );
      expect((await DeviceProfile.load()).isTv, isTrue);
    });

    test('si el canal falla, asume teléfono', () async {
      messenger.setMockMethodCallHandler(
        DeviceProfile.channel,
        (call) async => throw PlatformException(code: 'error'),
      );
      expect((await DeviceProfile.load()).isTv, isFalse);
    });
  });
}
