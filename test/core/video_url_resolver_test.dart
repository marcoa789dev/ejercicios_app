import 'package:ejercicios_app/core/utils/video_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = VideoUrlResolver();
  const driveId = '1A2B3C4D5E6F7G8H9';
  const driveDirect = 'https://drive.google.com/uc?export=download&id=$driveId';

  group('Google Drive', () {
    for (final url in [
      'https://drive.google.com/file/d/$driveId/view?usp=sharing',
      'https://drive.google.com/file/d/$driveId/preview',
      'https://drive.google.com/open?id=$driveId',
      'https://drive.google.com/uc?id=$driveId&export=download',
    ]) {
      test('convierte $url', () {
        final r = resolver.resolve(url);
        expect(r.source, VideoSource.googleDrive);
        expect(r.streamUrl, driveDirect);
      });
    }

    test('sin ID de archivo es un error', () {
      expect(
        () => resolver.resolve('https://drive.google.com/drive/my-drive'),
        throwsFormatException,
      );
    });
  });

  test('R2 público se detecta y se conserva tal cual', () {
    const url =
        'https://pub-39ad206303ce4d2fb6c50358e51f7725.r2.dev/cuello/semana-1/dia1-01-sesion.mp4';
    final r = resolver.resolve('  $url  ');
    expect(r.source, VideoSource.r2);
    expect(r.streamUrl, url);
  });

  test('cualquier otro https es MP4 directo', () {
    final r = resolver.resolve('https://ejemplo.com/video.mp4');
    expect(r.source, VideoSource.directMp4);
  });

  test('rechaza http, YouTube y texto que no es URL', () {
    for (final bad in [
      'http://ejemplo.com/video.mp4',
      'https://www.youtube.com/watch?v=XR_m6fU-WJA',
      'https://youtu.be/XR_m6fU-WJA',
      'no es una url',
      '',
    ]) {
      expect(() => resolver.resolve(bad), throwsFormatException, reason: bad);
    }
  });

  test('VideoSource se lee y escribe con el nombre de Firestore', () {
    expect(VideoSource.fromWire('google_drive'), VideoSource.googleDrive);
    expect(VideoSource.fromWire('r2'), VideoSource.r2);
    expect(VideoSource.fromWire('desconocido'), VideoSource.directMp4);
    expect(VideoSource.directMp4.wire, 'direct_mp4');
  });
}
