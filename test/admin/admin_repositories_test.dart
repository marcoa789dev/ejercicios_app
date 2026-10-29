import 'package:ejercicios_app/admin/catalog/video_arrangement.dart';
import 'package:ejercicios_app/core/data/firestore_catalog_admin_repository.dart';
import 'package:ejercicios_app/core/data/firestore_errors.dart';
import 'package:ejercicios_app/core/data/firestore_member_admin_repository.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/domain/member.dart';
import 'package:ejercicios_app/core/domain/repositories.dart';
import 'package:ejercicios_app/core/result.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCreator implements AccountCreator {
  final existing = <String>{};
  var _next = 0;

  @override
  Future<String> createAccount(String username, String password) async {
    if (!existing.add(username)) {
      throw const FailureException(AlreadyExistsFailure());
    }
    return 'uid-${++_next}';
  }
}

Video _video(
  String title, {
  int day = 1,
  int seconds = 60,
  String id = '',
  int order = 0,
}) => Video(
  id: id,
  playlistId: 'p1',
  categoryId: 'c1',
  title: title,
  dayNumber: day,
  order: order,
  streamUrl: 'https://x.r2.dev/$title.mp4',
  durationSeconds: seconds,
);

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  group('FirestoreCatalogAdminRepository', () {
    late FirestoreCatalogAdminRepository repo;

    setUp(() async {
      repo = FirestoreCatalogAdminRepository(db);
      await db.collection('playlists').doc('p1').set({
        'category_id': 'c1',
        'title': 'Semana 1',
        'week_number': 1,
        'order': 1,
        'is_active': true,
      });
    });

    Future<Map<String, dynamic>> playlist(String id) async =>
        (await db.collection('playlists').doc(id).get()).data()!;

    test('agregar videos recalcula los totales de la playlist', () async {
      await repo.saveVideo(_video('a', seconds: 100));
      await repo.saveVideo(_video('b', seconds: 50));
      await repo.saveVideo(_video('c', day: 3, seconds: 30));

      final p = await playlist('p1');
      expect(p['total_videos'], 3);
      expect(p['total_duration_seconds'], 180);
      expect(p['days_count'], 2);
    });

    test('un video nuevo va al final de su día', () async {
      await repo.saveVideo(_video('a'));
      await repo.saveVideo(_video('b'));
      final docs = (await db.collection('videos').get()).docs;
      final orders = {for (final d in docs) d['title']: d['order']};
      expect(orders, {'a': 1, 'b': 2});
    });

    test('desactivar un video lo saca de los totales', () async {
      final id =
          (await repo.saveVideo(_video('a', seconds: 100))) as Ok<String>;
      await repo.saveVideo(_video('b', seconds: 50));
      await repo.setVideoActive(_video('a', id: id.value), active: false);
      final p = await playlist('p1');
      expect(p['total_videos'], 1);
      expect(p['total_duration_seconds'], 50);
    });

    test('no se puede borrar una categoría con semanas', () async {
      final r = await repo.deleteCategory('c1');
      expect(r, isA<Err<void>>());
      expect((r as Err).failure, isA<NotEmptyFailure>());
    });

    test('duplicar copia los videos como la semana siguiente', () async {
      await repo.saveVideo(_video('a'));
      await repo.saveVideo(_video('b', day: 2));
      final r = await repo.duplicatePlaylist('p1', newTitle: 'Semana 2');
      final copyId = (r as Ok<String>).value;

      final copy = await playlist(copyId);
      expect(copy['title'], 'Semana 2');
      expect(copy['week_number'], 2);
      expect(copy['is_active'], isFalse);
      final videos = await db
          .collection('videos')
          .where('playlist_id', isEqualTo: copyId)
          .get();
      expect(videos.docs, hasLength(2));
    });

    test('borrar una playlist borra sus videos', () async {
      await repo.saveVideo(_video('a'));
      await repo.deletePlaylist('p1');
      expect((await db.collection('videos').get()).docs, isEmpty);
      expect((await db.collection('playlists').doc('p1').get()).exists, false);
    });

    test('reordenar solo escribe los que cambiaron', () async {
      for (final (id, order) in [('x', 1), ('y', 2), ('z', 3)]) {
        await db.collection('categories').doc(id).set({
          'name': id,
          'order': order,
        });
      }
      const x = Category(id: 'x', name: 'x', order: 1);
      const y = Category(id: 'y', name: 'y', order: 2);
      const z = Category(id: 'z', name: 'z', order: 3);
      await repo.reorderCategories(const [z, x, y]);
      final docs = (await db.collection('categories').get()).docs;
      expect(
        {for (final d in docs) d.id: d['order']},
        {'z': 1, 'x': 2, 'y': 3},
      );
    });
  });

  group('moveRow (arrastrar videos entre días)', () {
    final rows = buildRows([
      _video('a', id: 'a', order: 1),
      _video('b', id: 'b', order: 2),
      _video('c', id: 'c', day: 2, order: 1),
    ]);
    // [Día 1, a, b, Día 2, c, Día 3, …, Día 7]

    test('reordenar dentro del mismo día', () {
      final r = moveRow(rows, 2, 1); // b arriba de a
      expect(r.changed, [
        (id: 'b', dayNumber: 1, order: 1),
        (id: 'a', dayNumber: 1, order: 2),
      ]);
    });

    test('arrastrar debajo de otro encabezado cambia el día', () {
      final r = moveRow(rows, 1, 3); // a debajo de "Día 2"
      expect(r.changed, [
        (id: 'b', dayNumber: 1, order: 1),
        (id: 'a', dayNumber: 2, order: 1),
        (id: 'c', dayNumber: 2, order: 2),
      ]);
    });

    test('los encabezados no se mueven', () {
      expect(moveRow(rows, 0, 3).changed, isEmpty);
    });

    test('nada queda antes de "Día 1"', () {
      final r = moveRow(rows, 4, 0); // c hasta arriba
      expect(r.changed.first, (id: 'c', dayNumber: 1, order: 1));
    });
  });

  group('FirestoreMemberAdminRepository', () {
    late FakeCreator creator;
    late FirestoreMemberAdminRepository repo;

    setUp(() {
      creator = FakeCreator();
      repo = FirestoreMemberAdminRepository(db, creator);
    });

    Future<Result<Member>> create(String username) => repo.createMember(
      displayName: 'Mamá',
      username: username,
      password: 'secreto1',
      colorHex: '#7E57C2',
      avatar: 'flower',
    );

    test('crear un integrante escribe members y accounts', () async {
      final r = await create(' Mama ');
      final member = (r as Ok<Member>).value;
      expect(member.username, 'mama');

      final account = await db.collection('accounts').doc('uid-1').get();
      expect(account.data(), {
        'member_id': member.id,
        'username': 'mama',
        'is_active': true,
      });
    });

    test('un usuario repetido da AlreadyExistsFailure', () async {
      await create('mama');
      final r = await create('mama');
      expect((r as Err).failure, isA<AlreadyExistsFailure>());
    });

    test('desactivar corta la cuenta y desvincula su TV', () async {
      final member = ((await create('mama')) as Ok<Member>).value;
      await db.collection('tv_sessions').doc('tv1').set({
        'member_id': member.id,
      });

      await repo.setMemberActive(member, active: false);

      final account = await db.collection('accounts').doc('uid-1').get();
      expect(account['is_active'], isFalse);
      expect((await db.collection('tv_sessions').get()).docs, isEmpty);
    });

    test(
      'restablecer acceso enlaza la cuenta nueva y borra la vieja',
      () async {
        final member = ((await create('mama')) as Ok<Member>).value;
        creator.existing.clear(); // el admin borró la cuenta en la consola

        await repo.restoreAccess(member, newPassword: 'nueva123');

        expect(
          (await db.collection('accounts').doc('uid-1').get()).exists,
          false,
        );
        expect(
          (await db.collection('accounts').doc('uid-2').get()).exists,
          true,
        );
        final m = await db.collection('members').doc(member.id).get();
        expect(m['auth_uid'], 'uid-2');
      },
    );
  });
}
