import 'package:ejercicios_app/core/data/firestore_catalog_repository.dart';
import 'package:ejercicios_app/core/data/firestore_progress_repository.dart';
import 'package:ejercicios_app/core/domain/catalog.dart';
import 'package:ejercicios_app/core/utils/video_url_resolver.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  group('FirestoreCatalogRepository', () {
    late FirestoreCatalogRepository repo;

    setUp(() async {
      repo = FirestoreCatalogRepository(db);
      await db.collection('categories').doc('hombro').set({
        'name': 'Hombro',
        'order': 2,
        'is_active': true,
      });
      await db.collection('categories').doc('rodilla').set({
        'name': 'Rodilla',
        'order': 1,
        'is_active': true,
      });
      await db.collection('categories').doc('oculta').set({
        'name': 'Oculta',
        'order': 0,
        'is_active': false,
      });
      await db.collection('playlists').doc('rodilla-s1').set({
        'category_id': 'rodilla',
        'title': 'Semana de la rodilla',
        'level': 'intermediate',
        'order': 1,
        'is_active': true,
        'total_videos': 7,
        'total_duration_seconds': 25200,
      });
      for (final (id, day, order, active) in [
        ('d2', 2, 1, true),
        ('d1b', 1, 2, true),
        ('d1a', 1, 1, true),
        ('d3', 3, 1, false),
      ]) {
        await db.collection('videos').doc(id).set({
          'playlist_id': 'rodilla-s1',
          'category_id': 'rodilla',
          'title': 'Video $id',
          'day_number': day,
          'order': order,
          'video_source': 'r2',
          'stream_url': 'https://pub-x.r2.dev/$id.mp4',
          'duration_seconds': 3000,
          'is_active': active,
        });
      }
    });

    test('categorías activas ordenadas por order', () async {
      final cats = await repo.watchCategories().first;
      expect(cats.map((c) => c.name), ['Rodilla', 'Hombro']);
    });

    test('includeInactive también trae las desactivadas', () async {
      final cats = await repo.watchCategories(includeInactive: true).first;
      expect(cats.map((c) => c.id), ['oculta', 'rodilla', 'hombro']);
    });

    test('playlists de la categoría con sus campos mapeados', () async {
      final pls = await repo.watchPlaylists('rodilla').first;
      expect(pls, hasLength(1));
      expect(pls.single.level, Level.intermediate);
      expect(pls.single.totalDuration, const Duration(hours: 7));
    });

    test('videos activos ordenados por día y luego por orden', () async {
      final videos = await repo.watchVideos('rodilla-s1').first;
      expect(videos.map((v) => v.id), ['d1a', 'd1b', 'd2']);
      expect(videos.first.source, VideoSource.r2);
      expect(videos.first.duration, const Duration(minutes: 50));
    });
  });

  group('FirestoreProgressRepository', () {
    late FirestoreProgressRepository repo;

    setUp(() => repo = FirestoreProgressRepository(db));

    Future<Map<String, dynamic>> doc() async =>
        (await db
                .collection('members')
                .doc('mama')
                .collection('progress')
                .doc('p1')
                .get())
            .data()!;

    test('marcar y desmarcar completado', () async {
      await repo.setCompleted(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v1',
        completed: true,
      );
      await repo.setCompleted(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v2',
        completed: true,
      );
      await repo.setCompleted(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v1',
        completed: false,
      );
      expect((await doc())['completed_video_ids'], ['v2']);
    });

    test(
      'guardar el avance no pisa los completados ni otros avances',
      () async {
        await repo.setCompleted(
          memberId: 'mama',
          playlistId: 'p1',
          videoId: 'v1',
          completed: true,
        );
        await repo.savePosition(
          memberId: 'mama',
          playlistId: 'p1',
          videoId: 'v2',
          position: const Duration(seconds: 151),
        );
        await repo.savePosition(
          memberId: 'mama',
          playlistId: 'p1',
          videoId: 'v3',
          position: const Duration(minutes: 10),
        );

        final d = await doc();
        expect(d['completed_video_ids'], ['v1']);
        expect(d['positions'], {'v2': 151, 'v3': 600});
        expect(d['last_video_id'], 'v3');
      },
    );

    test('borrar el avance de un video deja los demás', () async {
      await repo.savePosition(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v2',
        position: const Duration(seconds: 151),
      );
      await repo.savePosition(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v3',
        position: const Duration(seconds: 30),
      );
      await repo.clearPosition(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v2',
      );
      expect((await doc())['positions'], {'v3': 30});
    });

    test('watchProgress entrega el progreso mapeado por playlist', () async {
      await repo.setCompleted(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v1',
        completed: true,
      );
      await repo.savePosition(
        memberId: 'mama',
        playlistId: 'p1',
        videoId: 'v2',
        position: const Duration(seconds: 90),
      );

      final all = await repo.watchProgress('mama').first;
      final p = all['p1']!;
      expect(p.isCompleted('v1'), isTrue);
      expect(p.positionOf('v2'), const Duration(seconds: 90));
      expect(p.lastVideoId, 'v2');
    });
  });
}
