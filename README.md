# Ejercicios App

Rutinas de ejercicio en video para la familia. Android (teléfono + Chromecast con Google TV), distribuido como APK.
Plan completo: [docs/PLAN_MAESTRO_APP_EJERCICIOS.md](docs/PLAN_MAESTRO_APP_EJERCICIOS.md).

| Flavor | APK | applicationId |
|---|---|---|
| `user` | Ejercicios (teléfono y Google TV) | `com.ejerciciosapp.app` |
| `admin` | Ejercicios Admin (solo teléfono) | `com.ejerciciosapp.admin` |

**Entorno:** Flutter 3.47.8 · Dart 3.13.7 · Android SDK 36.

## Comandos

```powershell
# Ejecutar
flutter run --flavor user  -t lib/main_user.dart
flutter run --flavor admin -t lib/main_admin.dart

# Probar un video de R2 (pantalla de prueba del Sprint 0)
flutter run --flavor user -t lib/main_user.dart --dart-define=TEST_VIDEO_URL=https://...

# Calidad
dart format lib test
flutter analyze
flutter test

# APKs
flutter build apk --release --flavor user  -t lib/main_user.dart
flutter build apk --release --flavor admin -t lib/main_admin.dart
```

## Chromecast con Google TV por WiFi

```powershell
adb connect <IP-del-Chromecast>:5555      # Android TV 12
# Android TV 14+: adb pair <IP>:<puerto> y luego adb connect <IP>:<puerto>
flutter run --flavor user -t lib/main_user.dart -d <IP>:5555
```

## Videos (resolución original, nunca se reescala)

Los videos viven en `Videos/{categoria}/semana-N/diaD-OO-titulo.mp4` (ignorado por git) y se publican en el bucket R2 `ejercicios-media`.

```powershell
.\tools\check_videos.ps1    -Dir .\Videos   # analiza códecs, resolución, duración y peso
.\tools\compress_videos.ps1 -Dir .\Videos   # H.264 misma resolución, ~41 % menos; reemplaza el original tras verificarlo
rclone copy .\Videos r2:ejercicios-media --include "*.{mp4,webp}" --progress
cd tools; npm install; node seed.mjs --dry-run; node seed.mjs   # carga tools/catalogo.csv en Firestore
```

## Reglas de Firestore

```powershell
cd rules_test; npm install; npm run test:emulador   # 26 pruebas contra el emulador
firebase deploy --only firestore:rules,firestore:indexes
```
