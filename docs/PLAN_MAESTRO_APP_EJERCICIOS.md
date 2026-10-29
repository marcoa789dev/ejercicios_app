# PLAN MAESTRO — "EJERCICIOS APP" (ADMIN + USUARIO, ANDROID MÓVIL + GOOGLE TV)

**Versión:** 3.3 — alcance definitivo (uso doméstico)
**Fecha:** 27 de octubre de 2026
**Documento base:** `documento_de_especificaciones_t_cnicas_y_planeaci_n.md` (sin modificar)

> **Cambios frente a la v2:** se confirmó que la app es **personal, para una casa, con 4 usuarios, solo Android (teléfono + Google TV), distribuida como APK sin Play Store, gratuita, solo en español, 1 administrador y ~50 videos (< 7 GB)**. Con eso se eliminan iOS, publicación en tiendas, requisitos legales de tiendas, App Check, Blaze y la escala de costos; y se añade el soporte completo de **Google TV** (control remoto / D-pad), que es el reto técnico principal.
>
> **Cambios de la v3.1:** cada integrante tiene **su propio usuario y contraseña**, creados por el admin desde la Admin App (sustituye a la cuenta familiar compartida); la TV es un **Chromecast con Google TV**; los videos están hoy en una **USB en MP4** (flujo en §8.3); Cloudflare R2 confirmado.
>
> **Cambios de la v3.2:** la TV inicia sesión **escaneando un QR** con el teléfono del integrante (§12.6), sin cuenta de TV; se añade **transmitir con Google Cast** desde el teléfono (§11.7); los videos se reproducen **siempre en su resolución original**, sin reescalar (§8.3–8.4).
>
> **Cambios de la v3.3:** el **avance de cada video se guarda en Firestore por integrante** y se reanuda donde se quedó, en cualquier dispositivo: teléfono, TV o Cast (§8.6). Pasa de *Should* a *Must*.

---

## ÍNDICE
0. Entorno de desarrollo
1. Alcance confirmado y su impacto
2. Requisitos
3. Decisiones de arquitectura (ADRs)
4. Arquitectura y estructura del proyecto
5. Dependencias
6. Modelo de datos Firestore
7. Reglas de seguridad
8. Videos: almacenamiento, codificación y reproducción
9. Admin App
10. User App (teléfono)
11. User App en Google TV
12. Autenticación e integrantes
13. Diseño UI/UX
14. Pruebas
15. Compilación, firma, instalación y actualizaciones
16. Costos
17. Roadmap por sprints
18. Riesgos
19. Guía de arranque (comandos)
20. Definition of Done y pendientes

---

## 0. ENTORNO DE DESARROLLO (revisado el 27/10/2026)

| Herramienta | Versión | Estado | Acción |
|---|---|---|---|
| Windows 10 Pro 22H2, i5-10400, 16 GB RAM, 291 GB libres | — | ✅ | — |
| Flutter (stable) | **3.47.8** (actualizado desde 3.41.9) | ✅ | Congelar esta versión durante el proyecto. |
| Dart SDK | **3.13.7** | ✅ | `sdk: ^3.13.0` en `pubspec.yaml`. |
| DevTools | 2.60.0 | ✅ | — |
| Android SDK | API 36.1, build-tools 36.1.0 / 37.0.0, NDK 27 / 28 | ✅ | — |
| Licencias de Android | — | ❌ | `flutter doctor --android-licenses` |
| adb (platform-tools 37.0.0) / emulador 36.5 | — | ⚠️ No están en el PATH; no hay emuladores creados | Agregar al PATH; crear un emulador de **teléfono** y uno de **Google TV** (§19.1). |
| JDK (el que trae Android Studio) | OpenJDK 21.0.10 | ✅ | — |
| Node.js / npm | 24.15.0 / 11.12.1 | ✅ | Para Firebase CLI y scripts. |
| Firebase CLI | 15.17.0 | ✅ Sesión iniciada como `marcoa789.dev@gmail.com` | Proyecto nuevo (no reutilizar `app-album-manager`). |
| FlutterFire CLI | 1.4.1 | ✅ | — |
| Git | 2.56.0 | ✅ | `git init` en el Sprint 0. |
| ffmpeg / ffprobe | build 2026-09-02 (gyan.dev, en `C:\ffmpeg\bin` y por winget) | ✅ | Para analizar y preparar los videos (§8.3). |
| rclone | — | ➕ | `winget install Rclone.Rclone` para subir los videos a R2. |
| Visual Studio (C++) | incompleto | — | **No hace falta** (no se compila para Windows). |
| Xcode / iOS | — | — | **Fuera del alcance.** |

---

## 1. ALCANCE CONFIRMADO Y SU IMPACTO

| Decisión | Valor | Impacto en el diseño |
|---|---|---|
| Nombre | **Ejercicios App** | IDs: `com.ejerciciosapp.app` (usuario) y `com.ejerciciosapp.admin` (admin). |
| Modelo | Gratuito | Sin pagos ni suscripciones. |
| Acceso | Abierto dentro de la casa | Todo el contenido visible para todos los integrantes; sin asignación de rutinas por usuario. |
| Admins | 1 | Basta con identificar al admin por su UID en las reglas; sin roles ni Custom Claims. |
| Usuarios | 4 | **Una cuenta por integrante** (usuario + contraseña) creada por el admin desde la Admin App; no hay registro abierto. En la TV, el integrante **escanea un QR** con su teléfono y la TV queda a su nombre. El progreso es por integrante y se comparte entre su teléfono y la TV. |
| Contenido | ~50 videos MP4 en una USB, < 7 GB | Cabe en el **nivel gratuito de Cloudflare R2 (10 GB)**. Se reproducen **en su resolución original**: no se reescala ni se baja la calidad. Si el códec es compatible basta con reacomodarlos (§8.3). |
| Plataformas | Android teléfono + **Chromecast con Google TV** | El APK de usuario lleva un *layout* de TV y navegación con D-pad. El control del Chromecast **no tiene teclas de reproducción**: todo se controla con el D-pad, OK y Atrás. Además, desde el teléfono se puede **transmitir con Google Cast** al Chromecast. |
| Idioma | Solo español | Textos en español (`es_MX`); no se necesita sistema de traducciones. |
| Distribución | APK instalado a mano (sin Play Store) | Sin fichas, revisiones, eliminación obligatoria de cuenta, prueba cerrada ni App Check (Play Integrity no sirve con APKs instalados a mano). |
| iOS | No | Sin Mac, sin Codemagic, sin cuenta de Apple. |

### Lo que se elimina de la v2
Cuenta de desarrollador de Google Play y de Apple, Codemagic, App Check, Custom Claims y su script, plan Blaze y Firebase Storage, flavors dev/prod con dos proyectos de Firebase, monorepo con *pub workspaces*, Sign in with Google/Apple, eliminación de cuenta, aviso de privacidad y términos, Analytics, analizador de costos a escala.

### Lo que se mantiene
Firestore como catálogo sincronizado en tiempo real, Firebase Auth, Crashlytics (gratis, útil para los errores en la TV), arquitectura por capas con BLoC, conversor de URLs, perfil de codificación de video, reproductor con manejo de errores, progreso por playlist.

### Lo que se añade
Soporte para Google TV, cuentas por integrante gestionadas desde la Admin App, inicio de sesión en la TV por QR, transmisión con Google Cast desde el teléfono, controles del reproductor propios (compatibles con el control remoto), guía de instalación por ADB y aviso de actualización del APK dentro de la app.

---

## 2. REQUISITOS

### 2.1 Admin App (solo teléfono)
| ID | Requisito | Prioridad |
|---|---|---|
| RF-A01 | Iniciar sesión con la cuenta de admin (email/contraseña). Cualquier otra cuenta ve "Sin permisos". | Must |
| RF-A02 | CRUD de categorías con reordenamiento por arrastre. | Must |
| RF-A03 | CRUD de playlists (semanas) por categoría, con nivel, objetivo, portada (URL) y reordenamiento. | Must |
| RF-A04 | CRUD de videos por playlist, agrupados por día (1–7), reordenables y movibles entre días. | Must |
| RF-A05 | Pegar una URL → detección del proveedor (R2/MP4/Drive) y conversión automática de Drive. | Must |
| RF-A06 | "Probar video": vista previa que verifica que reproduce y rellena la duración sola. | Must |
| RF-A07 | Recalcular automáticamente el total de videos y la duración de la playlist. | Must |
| RF-A08 | Activar/desactivar en lugar de borrar (borrado definitivo con confirmación). | Must |
| RF-A09 | Duplicar una playlist ("Semana 2" a partir de la "Semana 1"). | Should |
| RF-A10 | Gestionar integrantes: crear su cuenta (nombre, usuario, contraseña, color/avatar), desactivarla, restablecer su acceso si olvida la contraseña. | Must |
| RF-A12 | Ver si la TV está vinculada y a nombre de quién, y desvincularla. | Should |
| RF-A13 | Ver el progreso de cada integrante. | Could |
| RF-A11 | Publicar una versión nueva del APK de usuario (URL + número de versión) para el aviso de actualización. | Could |

### 2.2 User App (teléfono + Google TV, mismo APK)
| ID | Requisito | Prioridad |
|---|---|---|
| RF-U01 | Teléfono: cada integrante inicia sesión **una vez** con el usuario y la contraseña que le dio el admin (no hay pantalla de registro). | Must |
| RF-U02 | TV: muestra un **QR**; el integrante lo escanea desde la app de su teléfono y la TV entra a su nombre. "Salir" en la TV vuelve a mostrar el QR para que entre otra persona. | Must |
| RF-U03 | Home: categorías + tarjetas de playlists con % de progreso del integrante activo. | Must |
| RF-U04 | "Continuar": siguiente ejercicio pendiente de la última playlist del integrante. | Must |
| RF-U15 | Cambiar mi contraseña (pidiendo la actual). | Should |
| RF-U16 | **Transmitir** el video al Chromecast con Google Cast desde el teléfono, controlarlo desde el teléfono y seguir registrando el progreso. | Should |
| RF-U17 | Reproducir siempre en la **resolución original** del video, ajustado a la pantalla sin recortarlo ni deformarlo. | Must |
| RF-U05 | Detalle de playlist agrupado por días con estado (pendiente/completado). | Must |
| RF-U06 | Reproductor: play/pausa, ±10 s, barra de progreso, velocidad 0.75/1/1.25x, pantalla completa. | Must |
| RF-U07 | Instrucciones del ejercicio (series, repeticiones, texto). | Must |
| RF-U08 | Marcar/desmarcar completado + auto-completar al 90 % del video. | Must |
| RF-U09 | "Siguiente ejercicio" al terminar un video. | Must |
| RF-U10 | **Guardar el avance de cada video y reanudar donde se quedó**, por integrante y en cualquier dispositivo (teléfono, TV, Cast), incluso si la app se cierra de golpe o se pierde la conexión (§8.6). | Must |
| RF-U11 | Pantalla encendida durante la reproducción. | Must |
| RF-U12 | Error con "Reintentar" ante fallos de red o de video. | Must |
| RF-U13 | Navegación completa con el control remoto en Google TV (D-pad, OK, Atrás, Play/Pausa). | Must |
| RF-U14 | Aviso "Hay una nueva versión" con enlace de descarga del APK (solo teléfono). | Could |

### 2.3 No funcionales
| ID | Requisito |
|---|---|
| RNF-01 | El video empieza en ≤ 3 s en el WiFi de la casa (MP4 *faststart* desde R2). |
| RNF-02 | La interfaz va fluida en el Chromecast con Google TV (modelo HD: 1.5 GB RAM; modelo 4K: 2 GB RAM). |
| RNF-03 | Catálogo y progreso disponibles sin internet (caché de Firestore); el progreso se sincroniza al volver la conexión. |
| RNF-04 | `minSdk` 24 (Android 7.0); `targetSdk` 36. |
| RNF-05 | En la TV, todo elemento interactivo tiene un **indicador de foco** claramente visible a 3 m de distancia. |
| RNF-06 | Las reglas de Firestore solo permiten acceso al admin y a las cuentas que el admin dio de alta y siguen activas. |
| RNF-07 | Costo mensual: **USD 0**. |
| RNF-08 | Ningún paso del proceso cambia la resolución ni los fps de un video. |

---

## 3. DECISIONES DE ARQUITECTURA (ADRs)

| ADR | Decisión | Por qué |
|---|---|---|
| 001 | **Flutter 3.47 / Dart 3.13** | Instalado; un solo código para el teléfono, la TV y la Admin App. |
| 002 | **Un solo proyecto Flutter con 2 flavors** (`user`, `admin`) que producen 2 APKs | Más simple que un monorepo para 1 desarrollador; el código compartido vive en `lib/core`. Cada flavor tiene su propio `applicationId`, icono y nombre, así que pueden convivir en el mismo teléfono. |
| 003 | **flutter_bloc** (Cubit; Bloc para el reproductor) | Estados explícitos y fáciles de probar. |
| 004 | **Capas presentation / domain / data + repositorios**, DI con `get_it` | Separación clara; Firebase aislado en `data`. |
| 005 | **Admin identificado por UID en las reglas** (sin Custom Claims); el resto de las cuentas, en una lista `accounts/{uid}` que solo escribe el admin | Con 1 admin no hace falta un script con cuenta de servicio, y desactivar a alguien es cambiar un campo. |
| 006 | **Una cuenta por integrante + inicio de sesión en la TV por QR** | Cada quien entra con lo suyo en su teléfono. En la TV, escribir con el control remoto sería muy incómodo: la TV abre una sesión anónima sin permisos, muestra un QR, y el teléfono del integrante la aprueba. Funciona en el plan gratuito, sin Cloud Functions (§12.6). |
| 013 | **El admin crea las cuentas desde la app con una segunda instancia de Firebase** | Crear un usuario con el SDK normal cerraría la sesión del admin. Una instancia secundaria lo evita y funciona en el plan gratuito, sin Cloud Functions. |
| 014 | **Usuario en lugar de email**: `mama` se guarda en Firebase Auth como `mama@ejercicios.local` | Firebase Auth necesita un email; tu familia solo ve y escribe el usuario. |
| 015 | **Google Cast con el Default Media Receiver** | Reproduce MP4 directamente desde R2 sin registrar una app de Cast propia. Sprint 0: evaluar un paquete de Flutter para Cast (ej. `flutter_chrome_cast`); si no está mantenido o falla, un puente nativo pequeño con `play-services-cast-framework`. |
| 016 | **Resolución original siempre** | Decisión del usuario. Solo se reacomoda el archivo para que empiece rápido; se recodifica únicamente si el códec no es compatible, conservando resolución y fps. |
| 007 | **Cloudflare R2** para los videos (nivel gratuito) | 7 GB < 10 GB gratis, la salida de datos no cuesta y soporta adelantar/atrasar (*Range requests*). Drive falla con archivos > ~100 MB (página de aviso de virus) y tu promedio es ~140 MB por video. |
| 008 | **Plan Spark (gratuito) de Firebase**, sin Storage | Las portadas también van en R2; Firestore, Auth y Crashlytics son gratis a esta escala. |
| 009 | **`video_player` con controles propios** (sin `chewie`) | Los controles de `chewie` no están pensados para el D-pad; los propios permiten foco, teclas multimedia y la misma interfaz en teléfono y TV. |
| 010 | **go_router** | Rutas claras y redirecciones (login o QR en la TV → home). |
| 011 | ~~freezed + json_serializable~~ → **clases inmutables simples + mapeo manual** (cambio del Sprint 1) | Dart 3.13 introdujo la sintaxis de constructor `new(...)` y no conviene depender de que el generador de freezed la soporte todavía. El mapeo manual en `core/data/firestore_mappers.dart` además tolera documentos incompletos. Se puede reconsiderar freezed más adelante. |
| 012 | **APK universal** (sin `--split-per-abi`) | Muchos Google TV usan sistema de 32 bits aunque su CPU sea de 64; el APK universal funciona en todos. |

---

## 4. ARQUITECTURA Y ESTRUCTURA DEL PROYECTO

### 4.1 Sistema
```
 ┌──────────────────────────┐          ┌──────────────────────────────┐
 │  Cloudflare R2 (público) │◀─ HTTPS ─│ USER APP (teléfono / Google TV)│
 │  videos MP4 + portadas   │  Range   │ • Login con usuario/contraseña│
 └──────────▲───────────────┘          │ • Usuarios • Catálogo • Player│
            │ (subes con el            └───────────┬──────────────────┘
            │  panel de Cloudflare o rclone)       │ lee catálogo
            │                                      │ escribe progreso del integrante
 ┌──────────┴───────────────┐          ┌───────────▼──────────────────┐
 │ ADMIN APP (tu teléfono)  │─escribe─▶│ FIREBASE (plan Spark)        │
 │ • CRUD + reordenar       │          │ • Auth: admin+integrantes+TV │
 │ • Pegar URLs de R2       │          │ • Firestore: catálogo,       │
 │ • Probar video           │          │   integrantes, progreso      │
 └──────────────────────────┘          │ • Crashlytics                │
                                       └──────────────────────────────┘
```

### 4.2 Estructura de carpetas
```
ejercicios_app/
├── pubspec.yaml
├── analysis_options.yaml
├── firebase.json · firestore.rules · firestore.indexes.json
├── tools/
│   ├── check_videos.ps1         # ffprobe: analiza los videos de la USB (§8.3)
│   ├── prepare_videos.ps1       # ffmpeg: reacomoda o recodifica (§8.3–8.4)
│   └── seed.mjs                 # carga el catálogo desde catalogo.csv (§8.3)
├── android/app/
│   ├── build.gradle.kts         # productFlavors user/admin
│   └── src/
│       ├── main/AndroidManifest.xml
│       ├── user/                # manifest con LEANBACK_LAUNCHER, banner de TV, icono, google-services.json
│       └── admin/               # icono, google-services.json
└── lib/
    ├── main_user.dart           # entrada del flavor user
    ├── main_admin.dart          # entrada del flavor admin
    ├── bootstrap.dart           # Firebase, Crashlytics, get_it, caché de Firestore
    ├── firebase_options_user.dart / firebase_options_admin.dart
    ├── core/
    │   ├── domain/              # Category, Playlist, Video, Member, Account, PlaylistProgress, failures
    │   ├── data/                # DTOs, repositorios Firestore
    │   ├── utils/               # video_url_resolver.dart, result.dart, duration_format.dart
    │   └── platform/            # is_tv.dart (detecta Google TV)
    ├── ui_kit/                  # tema, colores, FocusableCard, ErrorView, EmptyView, ProgressBar
    ├── admin/                   # login, categories, playlists, videos, members, app_release
    └── user/                    # login, tv_link (QR en TV / escáner en teléfono), home, playlist, player, cast, settings, update_check
```
> Dart elimina el código que no se usa desde cada `main_*.dart`, así que el APK de usuario no incluye las pantallas de admin.

### 4.3 Flujo de datos
```
Widget ──▶ Cubit/Bloc ──▶ Repositorio (interfaz en domain) ──▶ Implementación Firestore (data)
   ▲            │                                                     │
   └── estado ◀─┘                         caché persistente de Firestore (offline)
```

### 4.4 Contratos de repositorio
```dart
abstract interface class CatalogRepository {
  Stream<List<Category>> watchCategories({bool includeInactive = false});
  Stream<List<Playlist>> watchPlaylists(String categoryId, {bool includeInactive = false});
  Stream<List<Video>> watchVideos(String playlistId, {bool includeInactive = false});
}

abstract interface class CatalogAdminRepository {
  Future<Result<String>> upsertCategory(Category c);
  Future<Result<void>> reorderCategories(List<String> orderedIds);
  Future<Result<String>> upsertPlaylist(Playlist p);
  Future<Result<String>> duplicatePlaylist(String id, {required String newTitle});
  Future<Result<void>> reorderPlaylists(String categoryId, List<String> orderedIds);
  Future<Result<String>> upsertVideo(Video v);              // recalcula agregados en una transacción
  Future<Result<void>> moveVideos(String playlistId, List<VideoPosition> positions);
  Future<Result<void>> deleteVideo(String videoId);
}

abstract interface class MemberRepository {
  Future<Result<Account>> getMyAccount();                  // accounts/{miUid}
  Future<Result<Member>> getMember(String memberId);
  Future<Result<void>> updateLastPlaylist(String memberId, String playlistId);
}

abstract interface class MemberAdminRepository {
  Stream<List<Member>> watchMembers();
  Future<Result<String>> createMember({required String displayName, required String username,
      required String password, required String colorHex, required String avatar});
  Future<Result<void>> updateMember(Member m);             // nombre, color, avatar, orden
  Future<Result<void>> setActive(String memberId, bool active);
  // Tras borrar la cuenta vieja en la consola de Firebase: crea una nueva con el mismo usuario
  // y la enlaza al mismo integrante, así conserva su progreso (§12.4)
  Future<Result<void>> restoreAccess(String memberId, {required String newPassword});
}

abstract interface class ProgressRepository {
  Stream<Map<String, PlaylistProgress>> watchProgress(String memberId);
  Future<Result<void>> setCompleted(String memberId, String playlistId, String videoId, bool done);
  // Avance del video (§8.6). savePosition escribe positions.{videoId} y last_video_id;
  // clearPosition lo borra al terminar el video o con "Empezar de nuevo".
  Future<Result<void>> savePosition(String memberId, String playlistId, String videoId, Duration position);
  Future<Result<void>> clearPosition(String memberId, String playlistId, String videoId);
}

abstract interface class TvLinkRepository {
  // En la TV
  Future<Result<TvLinkRequest>> createRequest();          // sesión anónima + nonce → contenido del QR
  Stream<TvSession?> watchMySession();                     // se dispara cuando un teléfono aprueba
  Future<void> leave();                                    // "Salir": borra la sesión y genera un QR nuevo
  // En el teléfono
  Future<Result<void>> approve(String qrPayload);          // escribe tv_sessions/{tvUid}
}

abstract interface class CastService {
  Stream<CastState> get state;                             // sin dispositivos / disponible / conectado
  Future<void> showDevicePicker();
  Future<void> load(Video v, {Duration startAt = Duration.zero});
  Future<void> playPause();
  Future<void> seek(Duration position);
  Stream<Duration> get position;                           // para el progreso y el 90 %
  Future<void> disconnect();
}

abstract interface class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<Result<AppUser>> signIn(String username, String password); // agrega @ejercicios.local
  Future<Result<void>> changePassword(String current, String next);
  Future<void> signOut();
}
```

---

## 5. DEPENDENCIAS

> Agregar con `flutter pub add` para obtener la última versión compatible con Flutter 3.47; el `pubspec.lock` se guarda en git.

| Paquete | Uso | Flavor |
|---|---|---|
| `firebase_core`, `firebase_auth`, `cloud_firestore` | backend | ambos |
| `firebase_crashlytics` | errores (clave para depurar en la TV) | ambos |
| `flutter_bloc` | estado | ambos |
| `go_router` | navegación | ambos |
| `get_it` | inyección de dependencias | ambos |
| `freezed_annotation`, `json_annotation` | modelos | ambos |
| `intl` | formato de duración/fechas en `es_MX` | ambos |
| `cached_network_image` | portadas en caché | ambos |
| `connectivity_plus` | aviso "sin conexión" | ambos |
| `video_player` | reproducción (ExoPlayer) | ambos (admin para "Probar video") |
| `wakelock_plus` | pantalla encendida | user |
| `shared_preferences` | preferencias locales del dispositivo (el avance de los videos va en Firestore, §8.6) | user |
| `package_info_plus` + `url_launcher` | aviso de actualización del APK | user |
| `qr_flutter` | dibujar el QR en la TV | user |
| `mobile_scanner` | escanear el QR con la cámara del teléfono | user |
| Paquete de Google Cast (a elegir en el Sprint 0, ADR-015) | transmitir al Chromecast | user |
| *dev:* `build_runner`, `freezed`, `json_serializable`, `very_good_analysis`, `bloc_test`, `mocktail`, `fake_cloud_firestore`, `firebase_auth_mocks` | codegen, lints, pruebas | — |

---

## 6. MODELO DE DATOS FIRESTORE

### 6.1 Convenciones
IDs generados por Firestore para lo que crea la Admin App; el catálogo cargado con `tools/seed.mjs` usa **IDs deterministas** (`rodilla`, `rodilla-s1`, `rodilla-s1-d1-01`) para poder volver a ejecutarlo sin duplicar; campos en `snake_case`; fechas con `serverTimestamp()`; `is_active` en todo el catálogo; `order` entero para el orden manual.

### 6.2 Catálogo
```json
// categories/{categoryId}
{ "name": "Rodilla", "description": "Fortalecimiento y movilidad", "icon": "knee",
  "color_hex": "#2E7D6B", "order": 1, "is_active": true,
  "created_at": "Timestamp", "updated_at": "Timestamp" }

// playlists/{playlistId}
{ "category_id": "…", "title": "Semana 1: Movilidad y desinflamación",
  "description": "Ejercicios de bajo impacto.", "goal": "Recuperar rango de movimiento",
  "thumbnail_url": "https://media…/rodilla/semana-1/portada.webp",
  "level": "beginner",                 // beginner | intermediate | advanced
  "week_number": 1, "order": 1, "is_active": true,
  "total_videos": 5, "total_duration_seconds": 2700, "days_count": 5,   // calculados
  "created_at": "Timestamp", "updated_at": "Timestamp" }

// videos/{videoId}
{ "playlist_id": "…", "category_id": "…",
  "title": "Extensiones pasivas de cuádriceps",
  "instructions": "Mantener 10 segundos cada repetición.", "sets": 3, "reps": 10,
  "day_number": 1, "order": 1,
  "video_source": "r2",               // r2 | direct_mp4 | google_drive
  "raw_url": "…lo que pegó el admin…",
  "stream_url": "https://media…/rodilla/semana-1/dia1-01-extensiones.mp4",
  "duration_seconds": 420, "thumbnail_url": "https://…", "is_active": true,
  "created_at": "Timestamp", "updated_at": "Timestamp" }
```

### 6.3 Integrantes, cuentas y progreso
```json
// members/{memberId}                 una persona de la familia. Su ID NO cambia aunque se
//                                    recree su cuenta de Auth → el progreso nunca se pierde
{ "display_name": "Mamá", "username": "mama", "color_hex": "#7E57C2", "avatar": "flower",
  "order": 1, "is_active": true, "auth_uid": "…UID actual en Firebase Auth…",
  "last_playlist_id": "…", "created_at": "Timestamp", "updated_at": "Timestamp" }

// accounts/{authUid}                 qué cuentas de Auth pueden entrar y como quién.
//                                    Solo el admin escribe aquí; las reglas lo consultan
{ "member_id": "…", "username": "mama", "is_active": true }

// tv_link_requests/{tvUid}           la TV (sesión anónima) publica un nonce aleatorio
{ "nonce": "…32+ caracteres aleatorios…", "created_at": "Timestamp" }

// tv_sessions/{tvUid}                el teléfono que escaneó el QR aprueba la TV
{ "member_id": "…", "nonce": "…el del QR…", "approved_by": "…uid del teléfono…",
  "created_at": "Timestamp", "expires_at": "Timestamp (máx. 12 h)" }

// members/{memberId}/progress/{playlistId}
{ "playlist_id": "…", "completed_video_ids": ["v1", "v2"],
  "positions": { "v3": 151 },          // segundos vistos de cada video a medias (§8.6)
  "last_video_id": "v3",               // el último que se estaba viendo → "Continuar"
  "started_at": "Timestamp", "updated_at": "Timestamp", "completed_at": null }

// app_config/latest_user_apk                   (opcional, RF-A11 / RF-U14)
{ "version_code": 7, "version_name": "1.2.0",
  "apk_url": "https://media…/apk/ejercicios-1.2.0.apk", "notes": "Nuevo modo TV" }
```
- **Avance del video:** `positions` solo guarda los videos que están a medias; al terminar uno se borra su entrada (`FieldValue.delete()`). Se escribe con `set(..., SetOptions(merge: true))` sobre `positions.{videoId}`, así no pisa el resto del documento. El tamaño está acotado por los videos de la playlist.
- **% de progreso** = videos activos de la playlist que están en `completed_video_ids` ÷ `total_videos` (la intersección evita pasar del 100 % si se borra un video).
- Marcar/desmarcar con `FieldValue.arrayUnion` / `arrayRemove`: funciona sin conexión y no se duplica.
- **Agregados** (`total_videos`, `total_duration_seconds`, `days_count`): la Admin App los recalcula en la misma `runTransaction` que guarda o borra el video.
- **Reordenar:** `WriteBatch` que reescribe `order` solo de los elementos que cambiaron de posición.

### 6.4 Índices compuestos (`firestore.indexes.json`)
```json
{
  "indexes": [
    { "collectionGroup": "categories", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "is_active", "order": "ASCENDING" },
                  { "fieldPath": "order", "order": "ASCENDING" } ] },
    { "collectionGroup": "playlists", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "category_id", "order": "ASCENDING" },
                  { "fieldPath": "is_active", "order": "ASCENDING" },
                  { "fieldPath": "order", "order": "ASCENDING" } ] },
    { "collectionGroup": "playlists", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "category_id", "order": "ASCENDING" },
                  { "fieldPath": "order", "order": "ASCENDING" } ] },
    { "collectionGroup": "videos", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "playlist_id", "order": "ASCENDING" },
                  { "fieldPath": "is_active", "order": "ASCENDING" },
                  { "fieldPath": "day_number", "order": "ASCENDING" },
                  { "fieldPath": "order", "order": "ASCENDING" } ] },
    { "collectionGroup": "videos", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "playlist_id", "order": "ASCENDING" },
                  { "fieldPath": "day_number", "order": "ASCENDING" },
                  { "fieldPath": "order", "order": "ASCENDING" } ] }
  ],
  "fieldOverrides": []
}
```

---

## 7. REGLAS DE SEGURIDAD (`firestore.rules`)

Firebase Auth deja que cualquiera con la API key (que va dentro del APK) cree una cuenta. Por eso las reglas **no** confían en "tener sesión": una cuenta solo entra si el admin la registró en `accounts/{uid}` y sigue activa.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Reemplazar por tu UID real (consola de Firebase > Authentication > Usuarios)
    function adminUid() { return 'ADMIN_UID_AQUI'; }

    function signedIn() { return request.auth != null; }
    function isAdmin()  { return signedIn() && request.auth.uid == adminUid(); }
    function accPath()  { return /databases/$(database)/documents/accounts/$(request.auth.uid); }
    function acc()      { return get(accPath()).data; }
    function isUser()   { return signedIn() && exists(accPath()) && acc().is_active == true; }

    // TV vinculada por QR: su UID anónimo tiene una sesión vigente de un integrante activo
    function tvPath()   { return /databases/$(database)/documents/tv_sessions/$(request.auth.uid); }
    function tvMember() { return get(tvPath()).data.member_id; }
    function isLinkedTv() {
      return signedIn() && exists(tvPath())
        && request.time < get(tvPath()).data.expires_at
        && get(/databases/$(database)/documents/members/$(tvMember())).data.is_active == true;
    }

    function isHouse()  { return isAdmin() || isUser() || isLinkedTv(); }
    // Quién registra progreso de un integrante: él mismo (teléfono o TV que vinculó) o el admin
    function canActAs(memberId) {
      return isAdmin()
        || (isUser() && acc().member_id == memberId)
        || (isLinkedTv() && tvMember() == memberId);
    }

    function validVideo() {
      let d = request.resource.data;
      return d.title is string && d.title.size() > 0 && d.title.size() <= 120
        && d.day_number is int && d.day_number >= 1 && d.day_number <= 7
        && d.stream_url is string && d.stream_url.matches('^https://.+')
        && d.video_source in ['r2', 'direct_mp4', 'google_drive'];
    }

    match /categories/{id} { allow read: if isHouse(); allow write: if isAdmin(); }
    match /playlists/{id}  { allow read: if isHouse(); allow write: if isAdmin(); }
    match /videos/{id} {
      allow read: if isHouse();
      allow create, update: if isAdmin() && validVideo();
      allow delete: if isAdmin();
    }
    match /app_config/{id} { allow read: if isHouse(); allow write: if isAdmin(); }

    match /accounts/{uid} {
      allow read: if isAdmin() || (signedIn() && request.auth.uid == uid);
      allow write: if isAdmin();
    }

    // La TV publica su solicitud (el nonce que va en el QR)
    match /tv_link_requests/{tvUid} {
      allow read, delete: if signedIn() && request.auth.uid == tvUid;
      allow create, update: if signedIn() && request.auth.uid == tvUid
        && request.resource.data.keys().hasOnly(['nonce', 'created_at'])
        && request.resource.data.nonce is string && request.resource.data.nonce.size() >= 32;
    }

    // El teléfono que escanea el QR aprueba la TV a nombre de SU integrante
    match /tv_sessions/{tvUid} {
      function involved() {
        return request.auth.uid == tvUid || isAdmin()
          || (isUser() && resource.data.member_id == acc().member_id);
      }
      allow read, delete: if signedIn() && involved();
      allow create, update: if isUser()
        && request.resource.data.member_id == acc().member_id
        && request.resource.data.approved_by == request.auth.uid
        && request.resource.data.nonce ==
             get(/databases/$(database)/documents/tv_link_requests/$(tvUid)).data.nonce
        && request.resource.data.expires_at is timestamp
        && request.resource.data.expires_at <= request.time + duration.value(12, 'h');
    }

    match /members/{memberId} {
      allow read: if isHouse();                 // nombres y colores para la interfaz
      allow create, delete: if isAdmin();
      // Un integrante solo puede tocar su "última playlist"; nombre, color y estado son del admin
      allow update: if isAdmin() || (canActAs(memberId) &&
        request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['last_playlist_id', 'updated_at']));

      match /progress/{playlistId} {
        allow read, delete: if canActAs(memberId);
        allow create, update: if canActAs(memberId)
          && request.resource.data.keys().hasOnly(['playlist_id', 'completed_video_ids',
               'positions', 'last_video_id', 'started_at', 'updated_at', 'completed_at'])
          && request.resource.data.playlist_id == playlistId
          && request.resource.data.get('completed_video_ids', []) is list
          && request.resource.data.get('completed_video_ids', []).size() <= 100
          && request.resource.data.get('positions', {}) is map
          && request.resource.data.get('positions', {}).size() <= 100;
      }
    }

    match /{document=**} { allow read, write: if false; }
  }
}
```
- Los UID **no son secretos**: no pasa nada porque estén en las reglas.
- **Desactivar a alguien** (`accounts/{uid}.is_active = false`) le corta el acceso al instante, aunque su sesión siga abierta.
- Un integrante puede leer los datos básicos de los demás (nombre, color), pero solo escribe su propio progreso.
- Una TV con sesión anónima **no ve nada** hasta que un integrante la aprueba, y entonces solo puede escribir el progreso de ese integrante. El nonce del QR impide aprobar una TV que no se tiene enfrente. La aprobación caduca a las 12 h, o antes si se desactiva al integrante.
- El admin puede revisar el progreso de todos desde la Admin App.
- Los videos en R2 son públicos para quien tenga la URL exacta. Para una app doméstica es un riesgo aceptable (las URLs no se publican en ningún lado).
- **Probar las reglas** con el emulador de Firebase antes de desplegarlas (§14).

---

## 8. VIDEOS

### 8.1 Almacenamiento: Cloudflare R2
| Opción | Veredicto |
|---|---|
| **Cloudflare R2** | ✅ **Elegida.** 10 GB gratis, salida de datos gratis, buen CDN, permite adelantar/atrasar. Cloudflare pide registrar una tarjeta para activar R2 aunque no se pase del nivel gratuito. |
| Google Drive | ❌ Los archivos de > ~100 MB devuelven una página de "no se puede analizar en busca de virus" en vez del video, y Drive limita las descargas. Con ~140 MB de promedio, la mayoría fallaría. El conversor la sigue soportando solo para pruebas rápidas. |
| Servidor en casa (PC/NAS con un servidor HTTP) | ⚠️ Alternativa sin tarjeta y sin internet, pero solo funciona dentro de la casa y con la PC encendida. |
| Firebase Storage | ❌ Requiere el plan Blaze; la descarga de datos se cobra. |

**Configuración de R2:**
1. Crear el bucket `ejercicios-media` (ubicación automática).
2. Activar el acceso público. Para 4 usuarios basta con la URL `https://pub-xxxx.r2.dev` (Cloudflare la limita en velocidad y la recomienda solo para desarrollo; si notas lentitud, conecta un dominio propio).
3. Subir los archivos desde el panel de Cloudflare (hasta 300 MB por archivo en el navegador) o con **rclone** para subirlos todos de una vez:
   ```powershell
   winget install Rclone.Rclone
   rclone config          # tipo "s3", proveedor "Cloudflare", con un token de API de R2
   rclone copy .\videos_listos r2:ejercicios-media --progress
   ```

**Estructura de carpetas en R2:**
```
rodilla/semana-1/portada.webp
rodilla/semana-1/dia1-01-extensiones-cuadriceps.mp4
rodilla/semana-1/dia1-01-extensiones-cuadriceps.webp   ← miniatura
apk/ejercicios-1.0.0.apk
```

### 8.2 Conversor de URLs (`lib/core/utils/video_url_resolver.dart`)
```dart
enum VideoSource { r2, directMp4, googleDrive }

class ResolvedVideoUrl {
  const ResolvedVideoUrl({required this.streamUrl, required this.source});
  final String streamUrl;
  final VideoSource source;
}

class VideoUrlResolver {
  const VideoUrlResolver();

  // Drive: /file/d/{ID}/view · /file/d/{ID}/preview · open?id={ID} · uc?id={ID}
  static final _drivePath = RegExp(r'/file/d/([a-zA-Z0-9_-]{10,})');
  static final _driveQuery = RegExp(r'[?&]id=([a-zA-Z0-9_-]{10,})');

  ResolvedVideoUrl resolve(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('La URL no es válida');
    }
    if (uri.scheme != 'https') throw const FormatException('La URL debe empezar con https://');
    if (uri.host.contains('youtube.com') || uri.host == 'youtu.be') {
      throw const FormatException('YouTube no es compatible con el reproductor de la app');
    }
    if (uri.host.endsWith('drive.google.com')) {
      final id = _drivePath.firstMatch(uri.path)?.group(1) ?? _driveQuery.firstMatch(input)?.group(1);
      if (id == null) throw const FormatException('No se encontró el ID del archivo de Drive');
      return ResolvedVideoUrl(
        streamUrl: 'https://drive.google.com/uc?export=download&id=$id',
        source: VideoSource.googleDrive,
      );
    }
    if (uri.host.endsWith('.r2.dev') || uri.host.endsWith('.r2.cloudflarestorage.com')) {
      return ResolvedVideoUrl(streamUrl: uri.toString(), source: VideoSource.r2);
    }
    return ResolvedVideoUrl(streamUrl: uri.toString(), source: VideoSource.directMp4);
  }
}
```
Pruebas unitarias: los 4 formatos de Drive, URL sin https, con espacios, YouTube, `r2.dev`, MP4 genérico.

### 8.3 De la USB a R2 (flujo completo)
1. **Copiar** la USB a `C:\Users\sis\Videos\Ejercicios\originales\` (la USB queda como respaldo). No meter los videos dentro del proyecto ni en git.
2. **Analizar** cada video con ffprobe (`tools/check_videos.ps1`, abajo): códec, resolución, duración, tamaño, y si basta con reacomodarlo o hay que recodificarlo.
3. **Preparar** en `C:\Users\sis\Videos\Ejercicios\listos\`:
   - Si el códec es compatible (video H.264 o HEVC; audio AAC o MP3) → **solo reacomodar** (segundos por archivo, misma calidad y resolución):
     `ffmpeg -i entrada.mp4 -c copy -movflags +faststart salida.mp4`
   - Si no → **recodificar** con el perfil de §8.4, **conservando la resolución y los fps originales**.
   - Sacar la miniatura de cada uno: `ffmpeg -ss 3 -i salida.mp4 -frames:v 1 -vf scale=640:-2 salida.webp`
4. **Verificar el total** (≤ 10 GB, el nivel gratuito de R2; con ~7 GB hay margen): `(Get-ChildItem C:\Users\sis\Videos\Ejercicios\listos\*.mp4 | Measure-Object Length -Sum).Sum / 1GB`
5. **Ordenar**: renombrar según la convención de §8.1 y llenar `catalogo.csv` con una fila por video:
   ```csv
   categoria,semana,titulo_semana,nivel,dia,orden,titulo,series,reps,instrucciones,archivo
   Rodilla,1,Movilidad y desinflamación,beginner,1,1,Extensiones pasivas de cuádriceps,3,10,"Mantener 10 s cada repetición",rodilla/semana-1/dia1-01-extensiones-cuadriceps.mp4
   ```
6. **Subir** a R2 con `rclone copy C:\Users\sis\Videos\Ejercicios\listos r2:ejercicios-media --progress`.
7. **Cargar el catálogo** con `node tools/seed.mjs catalogo.csv`: el script inicia sesión como admin con el SDK web de Firebase (sin cuenta de servicio), toma la duración del CSV de análisis y crea categorías, playlists y videos con sus totales. Así no hay que capturar los 50 videos a mano en la Admin App; después solo se ajusta lo que haga falta.

**`tools/check_videos.ps1`**
```powershell
param([string]$dir = "$env:USERPROFILE\Videos\Ejercicios\originales")
$rows = Get-ChildItem $dir -Filter *.mp4 -Recurse | ForEach-Object {
  $j = ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,pix_fmt:format=duration,size `
       -of json $_.FullName | ConvertFrom-Json
  $v = $j.streams | Where-Object codec_type -eq 'video' | Select-Object -First 1
  $a = $j.streams | Where-Object codec_type -eq 'audio' | Select-Object -First 1
  $ok = $v.codec_name -in @('h264', 'hevc') -and (-not $a -or $a.codec_name -in @('aac', 'mp3'))
  [pscustomobject]@{
    Archivo    = $_.FullName.Substring($dir.Length + 1)
    Video      = $v.codec_name
    Audio      = $a.codec_name
    Resolucion = "$($v.width)x$($v.height)"
    Duracion_s = [int][double]$j.format.duration
    MB         = [math]::Round([double]$j.format.size / 1MB)
    Accion     = if ($ok) { 'reacomodar' } else { 'recodificar' }
    Aviso      = if ($v.height -gt 1080) { 'Más de 1080p: solo lo reproduce el Chromecast 4K' }
                 elseif ($v.codec_name -eq 'hevc') { 'HEVC: probar en los teléfonos más antiguos' }
                 else { '' }
  }
}
$rows | Format-Table -AutoSize
$rows | Export-Csv (Join-Path (Split-Path $dir) 'analisis_videos.csv') -NoTypeInformation -Encoding utf8
'Total: {0:N2} GB' -f (($rows | Measure-Object MB -Sum).Sum / 1024)
```

### 8.4 Perfil de recodificación (solo para los marcados "recodificar")
Solo para videos con un códec que el Chromecast o los teléfonos no reproducen bien. **No se cambia la resolución ni los fps** (sin filtro `scale` ni `fps`); se usa una calidad casi sin pérdida (CRF 18).

```powershell
# tools/prepare_videos.ps1 — recodifica SOLO los marcados "recodificar" (misma resolución y fps)
# uso: .\tools\prepare_videos.ps1 .\por_recodificar .\listos
param([string]$inDir, [string]$outDir)
New-Item -ItemType Directory -Force $outDir | Out-Null
Get-ChildItem $inDir -Include *.mp4,*.mov,*.mkv -Recurse | ForEach-Object {
  $out = Join-Path $outDir ($_.BaseName + '.mp4')
  ffmpeg -y -i $_.FullName `
    -c:v libx264 -profile:v high -preset slow -crf 18 -pix_fmt yuv420p `
    -c:a aac -b:a 160k -movflags +faststart $out
  ffmpeg -y -ss 3 -i $out -frames:v 1 -vf scale=640:-2 ($out -replace '\.mp4$', '.webp')
}
```
| Parámetro | Por qué |
|---|---|
| H.264 High, `yuv420p` | Lo decodifica por hardware cualquier teléfono o Chromecast |
| Sin `scale` ni `fps` | Resolución y fps **originales** (decisión del proyecto) |
| CRF 18 | Casi sin pérdida visible; el archivo puede salir algo más pesado que el original |
| AAC 160 kbps | Compatible con todo |
| `+faststart` | **Obligatorio**: el video empieza a reproducirse sin descargarse completo |

**En pantalla:** la app muestra el video con su relación de aspecto (`AspectRatio` + `BoxFit.contain`), sin recortarlo ni deformarlo. Que un video de 720p ocupe toda la TV es el ajuste normal de la pantalla, no un reescalado del archivo.

### 8.5 Reproductor (`PlayerBloc`)
- `VideoPlayerController.networkUrl(...)` con un límite de 15 s para iniciar.
- Estados: `initializing → ready(playing | paused) → buffering → completed | failure(network | timeout | source)`.
- Mensajes: *Sin conexión* (Reintentar) · *El video tarda demasiado* (Reintentar) · *Este video no está disponible* (se reporta a Crashlytics con el ID del video).
- Guardar el avance y reanudar donde se quedó: §8.6.
- Al 90 %: marcar como completado automáticamente.
- `WakelockPlus.enable()` al reproducir y `disable()` al pausar o salir.
- Controles propios que funcionan igual con el dedo y con el control remoto (§11.4).

### 8.6 Guardar el avance y reanudar (RF-U10)
**Objetivo:** si alguien deja un video a medias, al volver a abrirlo (en el mismo u otro dispositivo) sigue donde se quedó.

**Cuándo se guarda** (`ProgressRepository.savePosition`, en `members/{id}/progress/{playlistId}.positions.{videoId}`):
| Momento | Por qué |
|---|---|
| Cada **10 s** mientras se reproduce, solo si avanzó ≥ 5 s desde la última vez | Si la app se cierra de golpe o se va la luz, se pierden como máximo 10 s |
| Al **pausar** | Lo más común antes de dejar el video |
| Al **adelantar o atrasar** (al soltar la barra o tras ±10 s) | Guarda el punto elegido |
| Al **salir** del reproductor (Atrás, siguiente ejercicio) | Cierre normal |
| Cuando la app pasa a **segundo plano** (`AppLifecycleState.paused`/`inactive`): botón Inicio, llamada, pantalla apagada, TV apagada | Casos en que la app puede morir sin aviso |
| Durante **Cast**, cada 10 s con la posición que reporta el Chromecast | El teléfono es quien guarda |

**Cuándo se borra** (`clearPosition`): al llegar al **95 %** o al final del video (además de marcarlo completado al 90 %), y con el botón "Empezar de nuevo".

**Cómo se reanuda:**
1. Al abrir un video se lee `positions.{videoId}` (desde la caché de Firestore, así que es instantáneo y funciona sin red).
2. Si hay avance **entre 5 s y el 95 %** de la duración: se empieza **3 s antes** del punto guardado, para retomar el movimiento del ejercicio.
3. Aparece un aviso durante 6 s: **"Continuando desde 02:31 · [Empezar de nuevo]"**. En la TV, el botón se alcanza con ↓ y OK sigue siendo Play/Pausa.
4. Si no hay avance o pasa del 95 %: empieza desde 0.
5. Los videos completados que se vuelven a abrir empiezan desde 0 (repetir un ejercicio es lo normal).

**Dónde se ve el avance:**
- **Home → "Continuar":** usa `last_playlist_id` + `last_video_id` + su posición. Ejemplo: "Continuar · Extensiones de cuádriceps · 02:31 de 07:00", con una barra pequeña.
- **Detalle de playlist:** los videos a medias muestran una barra de avance bajo la miniatura y el texto "Visto 02:31 de 07:00" en lugar de ○.

**Varios dispositivos:** si el mismo integrante ve un video en el teléfono y luego en la TV, gana el último guardado (`updated_at`). Sin conexión, Firestore guarda las escrituras en la cola local y las sube al reconectar.

**Costo:** ~6 escrituras por minuto de video. Con 4 personas × 1 h/día son ≈ 1 500 escrituras/día; el límite gratuito es de 20 000.

**Pruebas:** `bloc_test` del `PlayerBloc`: guarda cada 10 s, al pausar, al salir y al ir a segundo plano; reanuda 3 s antes; no reanuda por debajo de 5 s ni por encima del 95 %; borra al terminar. Con `fake_cloud_firestore`: la escritura con *merge* no pisa `completed_video_ids`.

---

## 9. ADMIN APP (teléfono)

### 9.1 Navegación
```
/login → /categories → /categories/:id/playlists → /playlists/:id/videos
                │                 │                         └─ /videos/new · /videos/:id/edit
                │                 └─ /playlists/new · /playlists/:id/edit
                ├─ /categories/new · /categories/:id/edit
                ├─ /members             (integrantes y TV vinculada)
                └─ /release             (versión del APK, opcional)
Guardia: sin sesión → /login · sesión con un UID distinto del admin → "Sin permisos" + cerrar sesión
```

### 9.2 Pantallas
- **Login:** email y contraseña; errores en español (`invalid-credential`, `too-many-requests`, `network-request-failed`).
- **Categorías:** lista reordenable (`ReorderableListView`) con color, nombre, nº de playlists y chip "Inactiva". Reordenar actualiza la pantalla de inmediato y guarda en un batch; si falla, se revierte con un aviso.
- **Formulario de categoría:** nombre (1–60), descripción, ícono (cuadrícula), color (paleta fija), activa.
- **Playlists:** lista reordenable con portada, título, nivel, nº de videos, duración total. Acciones: editar, duplicar, activar/desactivar.
- **Formulario de playlist:** título, semana nº, descripción, objetivo, nivel (selector), URL de la portada con vista previa, activa. Avisa si se activa sin videos.
- **Videos:** secciones Día 1 … Día 7, cada una reordenable con "+ Agregar al día N"; "Mover a día…" en el menú de cada video.
- **Formulario de video:**
  1. Pegar la URL → chip con el proveedor detectado y la URL final. Drive: aviso amarillo "Solo para pruebas". YouTube: error.
  2. **Probar video**: reproduce unos segundos en la pantalla y rellena la duración sola. Si falla en 15 s, no deja guardar sin confirmar.
  3. Título, día, instrucciones, series y repeticiones (opcionales), URL de la miniatura, activo.
  4. Guardar = transacción que guarda el video y recalcula la playlist.
- **Integrantes:** lista con nombre, usuario, color, avatar y estado (activo/inactivo); reordenable.
  - **Nuevo integrante:** nombre, usuario (3–20 caracteres: minúsculas, números, `.`, `_`, `-`), contraseña (mín. 6, botón "Generar"), color y avatar. Al guardar muestra una tarjeta "Usuario: mama · Contraseña: …" para que se la pases a esa persona.
  - **TV:** a nombre de quién está vinculada ahora y botón "Desvincular".
  - **Desactivar / activar** el acceso de alguien.
  - **Restablecer acceso** si alguien olvidó su contraseña (§12.4).
  - **Ver progreso** de cada integrante (opcional).
- **Versión del APK (opcional):** número de versión y URL del APK subido a R2 → escribe `app_config/latest_user_apk`.

### 9.3 Borrado
Por defecto se **desactiva**. Borrado definitivo: categoría solo si está vacía; playlist con confirmación (borra también sus videos en un batch); video con confirmación simple (recalcula la playlist).

### 9.4 Estados de cada lista
Cargando (shimmer) · Vacía (mensaje + botón "Crear…") · Error (Reintentar) · Datos · Aviso "Sin conexión: los cambios se guardarán al reconectar".

---

## 10. USER APP — TELÉFONO

### 10.1 Navegación
```
/splash → (teléfono sin sesión) /login  ·  (TV sin vincular) /tv-link (QR)  → /home
                                                              ├─ /playlist/:id → /player/:videoId
                                                              └─ /settings (vincular TV, cambiar contraseña, versión, buscar actualización)
```

### 10.2 Pantallas
- **Splash:** inicia Firebase y lee `accounts/{miUid}`: teléfono sin sesión → login; TV sin vincular → QR; cuenta de integrante o TV vinculada → home; cuenta desactivada o no registrada → "Tu acceso está desactivado, habla con el administrador" + cerrar sesión.
- **Login:** campos **Usuario** y **Contraseña** (la app agrega `@ejercicios.local` por dentro). Sin "Registrarse" ni "Olvidé mi contraseña": en su lugar, el texto "¿Olvidaste tu contraseña? Pídele al administrador que restablezca tu acceso".
- **Vincular TV** (Ajustes, y también un botón en el Home si hay una TV esperando): abre la cámara, escanea el QR de la TV y confirma "¿Entrar en la TV como {nombre}?" (§12.6).
- **Home:**
  - Saludo "Hola, {nombre}" (en la TV, con un botón "Salir" que vuelve al QR para que entre otra persona).
  - Tarjeta **Continuar** → el video a medias (`last_video_id`) en el segundo exacto donde se quedó; si no hay ninguno a medias, el siguiente pendiente de `last_playlist_id` (§8.6).
  - Chips de categorías.
  - Tarjetas de playlists: portada 16:9, título, nivel, "5 ejercicios · 45 min", barra con %, ✓ al 100 %.
- **Detalle de playlist:** portada, objetivo, nivel, duración total; lista por días ("Día 1 · 2 ejercicios · 12 min") con ○ / barra de avance "Visto 02:31 de 07:00" / ✓; botón "Empezar" o "Continuar día N".
- **Reproductor:**
```
┌───────────────────────────────┐
│          VIDEO 16:9           │  tocar: mostrar/ocultar controles
│  ⟲10    ▶/❚❚    10⟳   1x   ⛶  │  doble toque a los lados: ∓10 s
│  ━━━━━━━━●──────── 02:31/07:00 │
├───────────────────────────────┤
│ Día 1 · Ejercicio 1 de 2      │
│ Extensiones pasivas de cuádriceps
│ 3 series × 10 repeticiones    │
│ ▾ Instrucciones               │
├───────────────────────────────┤
│ [ ✓ Marcar como completado ]  │
│ [ Siguiente ejercicio → ]     │
└───────────────────────────────┘
```
  Al terminar la playlist: pantalla de felicitación + sugerir la siguiente semana.
  Botón **Cast** en la barra superior del reproductor (solo si hay un Chromecast en la red): §11.7.
- **Ajustes:** cambiar mi contraseña (pide la actual), cerrar sesión, versión instalada, "Buscar actualización" (compara `version_code` con `app_config/latest_user_apk` y abre la URL del APK).

---

## 11. USER APP — GOOGLE TV

Es el mismo APK de usuario. Al detectar una TV cambia el *layout* y el modo de navegación.

### 11.1 Manifest del flavor `user` (`android/app/src/user/AndroidManifest.xml`)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- No exigir pantalla táctil ni leanback: así instala en teléfono Y en TV -->
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />
    <uses-feature android:name="android.software.leanback" android:required="false" />

    <application android:banner="@drawable/tv_banner">   <!-- PNG 320×180 px -->
        <activity android:name=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <!-- Hace que aparezca en la pantalla de inicio de Google TV -->
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```
Sin `LEANBACK_LAUNCHER` la app se instala pero **no aparece** en el inicio de Google TV.

### 11.2 Detectar la TV (`lib/core/platform/is_tv.dart`)
Un `MethodChannel` mínimo en `MainActivity.kt` que devuelve
`packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)`, cargado una vez en `bootstrap()` y registrado en `get_it` como `DeviceProfile(isTv: true/false)`.

### 11.3 Navegación con el control remoto
- Flutter mueve el foco con las flechas del D-pad (`DirectionalFocusIntent`). Verificar en el dispositivo que el botón **OK/centro** active el elemento enfocado; si no, añadir en `MaterialApp.shortcuts`:
  ```dart
  shortcuts: {
    ...WidgetsApp.defaultShortcuts,
    const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
    const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
  },
  ```
- **Atrás** del control remoto = botón atrás de Android (go_router lo maneja).
- Cada pantalla define el **foco inicial** (`autofocus: true` en el primer elemento útil: el botón "Continuar", el primer integrante, el botón "Empezar").
- Las filas horizontales van en `FocusTraversalGroup` para que arriba/abajo cambie de fila y izquierda/derecha recorra la fila; al recibir foco, la tarjeta se desplaza a la vista (`Scrollable.ensureVisible`).
- Componente `FocusableCard` en `ui_kit`: con foco se agranda un 8 %, gana un borde de 3 px en el color primario y una sombra; animación de 150 ms.

### 11.4 Reproductor en TV
| Tecla | Acción |
|---|---|
| OK / centro | Mostrar controles; si ya se ven, Play/Pausa |
| ← / → (controles ocultos) | −10 s / +10 s |
| ↑ / ↓ | Mostrar controles y mover el foco entre la barra de controles y los botones de abajo |
| Play/Pausa, Avance rápido, Retroceso (`LogicalKeyboardKey.mediaPlayPause`, `mediaFastForward`, `mediaRewind`) | Lo que indican |
| Atrás | Ocultar controles; si ya están ocultos, salir |

> **El control del Chromecast con Google TV no tiene botones de reproducción** (solo D-pad, OK, Atrás, Inicio, Asistente, accesos directos, volumen y entrada). Por eso todo el reproductor debe poder usarse **solo con el D-pad, OK y Atrás**. Las teclas multimedia se soportan igual porque funcionan con el control remoto de la app Google Home y con otros controles.

Los controles se ocultan tras 4 s sin actividad. En TV el video siempre ocupa toda la pantalla; las instrucciones y "Marcar como completado" aparecen en un panel inferior al pulsar ↓ y en la pantalla de fin del video.

### 11.5 Diseño "a 3 metros"
- Pantalla de 1920×1080 ≈ 960×540 puntos lógicos en Flutter: diseñar con ese tamaño en mente.
- Margen de seguridad del 5 % en los bordes (algunas TVs recortan la imagen).
- Texto mínimo 18 sp (cuerpo) y 28–36 sp (títulos).
- Home en TV: filas horizontales por categoría (como en las apps de streaming) en lugar de chips.
- Fondo oscuro por defecto en TV (menos brillo en la sala).
- Sin elementos que solo funcionen con gestos (arrastrar, deslizar, mantener presionado).

### 11.6 Rendimiento en TV
- Los Google TV de gama baja tienen CPU y RAM limitadas: animaciones cortas, `memCacheWidth` en las portadas (decodificar al tamaño mostrado), listas con `ListView.builder`.
- Flutter usa el motor gráfico Impeller en Android por defecto. Si en algún TV aparecen fallos de dibujo, desactivarlo agregando en el manifest:
  `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />`
- Medir con `flutter run --profile` en el dispositivo real.

### 11.7 Transmitir desde el teléfono (Google Cast)
Es otra forma de ver los videos en la TV, sin usar la app del Chromecast: el teléfono hace de control remoto.
1. En el reproductor del teléfono, el botón Cast aparece cuando hay un Chromecast en la misma red WiFi.
2. Al elegirlo, el teléfono envía la `stream_url` de R2 al **Default Media Receiver** del Chromecast, con título y miniatura. El Chromecast descarga el video directamente de R2, en su resolución original.
3. El teléfono muestra controles remotos: play/pausa, ±10 s, barra de progreso, "Siguiente ejercicio" (envía el siguiente video).
4. El progreso sigue funcionando: el teléfono lee la posición del Chromecast y marca el video como completado al 90 % o con el botón.
5. Al desconectar, el video sigue en el teléfono desde la misma posición.
6. Al empezar a transmitir un video a medias, se envía con `startAt` = posición guardada − 3 s; el avance se sigue guardando cada 10 s (§8.6).

| Detalle | Valor |
|---|---|
| Receptor | Default Media Receiver (no requiere registro en la consola de Google Cast) |
| Requisitos | Teléfono con Google Play Services y en la misma red WiFi que el Chromecast |
| Formatos | Los MP4 de R2 tal como están (H.264/HEVC + AAC) |
| Velocidad 0.75x/1.25x | Puede no estar disponible al transmitir; se oculta si el receptor no la soporta |

**¿App en la TV o transmitir?** Las dos conviven. La app de la TV sirve cuando nadie tiene el teléfono a mano (se entra con el QR y se usa el control remoto); transmitir es lo más rápido cuando ya se está viendo la rutina en el teléfono.

---

## 12. AUTENTICACIÓN E INTEGRANTES

### 12.1 Tipos de cuenta
| Cuenta | Quién la crea | Uso | Dónde inicia sesión |
|---|---|---|---|
| Admin (tu email real) | Tú, en la consola de Firebase (una vez) | Gestionar contenido e integrantes | Admin App en tu teléfono |
| Integrante (ej. `mama`) | Tú, desde la Admin App | Ver y registrar **su** progreso | User App en su teléfono |
| TV | Nadie: abre una sesión anónima por sí sola | Mostrar el QR; queda como el integrante que lo escaneó | User App en el Chromecast |

- Proveedores de Firebase Auth: **Email/contraseña** (admin e integrantes) y **Anónimo** (solo para que la TV pueda mostrar el QR; una sesión anónima no ve nada hasta que alguien la aprueba). No hay pantalla de registro.
- El usuario se guarda como `{usuario}@ejercicios.local`; la familia nunca ve ese email. Ese dominio no existe, así que Firebase no puede enviar correos de recuperación: el restablecimiento lo haces tú (§12.4). En el Sprint 0 se comprueba que Firebase acepta el dominio; si no, se usa otro sufijo fijo.
- Tu UID va en `firestore.rules` (§7). Si tú también haces ejercicio, te creas una cuenta de integrante para ti.

### 12.2 Crear una cuenta desde la Admin App
Con el SDK normal, `createUserWithEmailAndPassword` **inicia sesión con la cuenta nueva** y cerraría la tuya. Se usa una segunda instancia de Firebase solo para crearla:
```dart
Future<String> createAuthUser(String username, String password) async {
  final secondary = await Firebase.initializeApp(
    name: 'account-creator',
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    final auth = FirebaseAuth.instanceFor(app: secondary);
    final cred = await auth.createUserWithEmailAndPassword(
      email: '$username@ejercicios.local',
      password: password,
    );
    await auth.signOut();
    return cred.user!.uid;
  } finally {
    await secondary.delete();
  }
}
```
Después, con tu sesión de admin, un `WriteBatch` crea `members/{id}` (con `auth_uid`) y `accounts/{uid}`. Si el usuario ya existe, Firebase devuelve `email-already-in-use` → mensaje "Ese usuario ya está ocupado".

### 12.3 Desactivar a alguien
`accounts/{uid}.is_active = false` (y `members/{id}.is_active = false`). Las reglas le cortan el acceso al instante; en su teléfono la app muestra "Tu acceso está desactivado". Para borrar la cuenta de Auth del todo: consola de Firebase → Authentication → eliminar.

### 12.4 Si alguien olvida su contraseña
Cambiar la contraseña **de otra persona** solo se puede con el Admin SDK, que requiere un servidor o Cloud Functions (plan Blaze). Para seguir en el plan gratuito:
1. Consola de Firebase → Authentication → busca `mama@ejercicios.local` → **Eliminar cuenta**.
2. Admin App → Integrantes → Mamá → **Restablecer acceso** → nueva contraseña.
3. La app crea una cuenta nueva con el mismo usuario, actualiza `members/{id}.auth_uid` y reemplaza `accounts/{uid}`. **El progreso se conserva** porque está guardado bajo el integrante, no bajo la cuenta.

> Si esto se vuelve frecuente, una Cloud Function `resetMemberPassword` (~30 líneas) lo hace con un botón; requiere activar Blaze, pero a este uso queda dentro del nivel gratuito.

### 12.5 Cambiar la propia contraseña
Ajustes → "Cambiar mi contraseña": `reauthenticateWithCredential` con la actual y luego `updatePassword`.

### 12.6 Inicio de sesión en la TV por QR
```
   CHROMECAST (app)                         FIRESTORE                       TELÉFONO (ya con sesión)
1. signInAnonymously()  ── (sin permisos todavía)
2. nonce aleatorio ─────────────▶ tv_link_requests/{tvUid}
3. Muestra QR:  ejerciciosapp://tv-link?tv={tvUid}&n={nonce}
                                                              4. Ajustes → Vincular TV → escanea
                                                              5. "¿Entrar en la TV como Mamá?" → Sí
                                  tv_sessions/{tvUid} ◀────────── {member_id, nonce, expires_at}
                                  (las reglas verifican que el nonce coincide)
6. Escucha tv_sessions/{tvUid} ◀─ aparece la sesión
7. Entra al Home como "Mamá"; su progreso se guarda en members/{mamá}
8. "Salir" → borra tv_sessions y tv_link_requests → nonce nuevo → QR nuevo
```
- **Sin escribir nada en la TV** y sin Cloud Functions: el permiso lo da el teléfono, y las reglas (§7) solo lo aceptan si el nonce coincide con el que publicó la TV.
- **El QR cambia** cada vez que se sale, y también cada 10 minutos mientras nadie lo escanea, para que una foto vieja del QR no sirva.
- **Duración:** la TV queda a nombre del integrante hasta que pulsa "Salir" o pasan **12 horas**; luego vuelve al QR.
- **Cambiar de persona:** "Salir" en la TV y que el otro integrante escanee.
- **Desactivar a un integrante** también cierra su sesión en la TV.
- La TV conserva su UID anónimo entre aperturas, así que no crea cuentas nuevas cada vez.
- Para el texto del QR en la TV: "Escanea con la app Ejercicios en tu teléfono → Ajustes → Vincular TV". Tamaño mínimo del QR: 240×240 puntos lógicos, sobre fondo blanco.

---

## 13. DISEÑO UI/UX

- Material 3 con `ColorScheme.fromSeed(seedColor: Color(0xFF2E7D6B))`; tema claro y oscuro en el teléfono, oscuro en la TV.
- Colores de estado: completado `#2E7D32` / `#81C784`, aviso `#ED6C02`, error `#C62828`.
- Bordes de tarjetas de 16, espaciado en múltiplos de 4.
- Botones principales de 56 dp de alto en el teléfono.
- El estado nunca se indica solo con color: siempre ícono ✓ + texto.
- Etiquetas `Semantics` en tarjetas y controles del reproductor.
- Componentes compartidos del `ui_kit`: `FocusableCard`, `PlaylistCard`, `MemberAvatar`, `ProgressBar`, `DayHeader`, `VideoRow`, `PrimaryButton`, `ErrorView(onRetry)`, `EmptyView`, `OfflineBanner`, `ShimmerList`.
- Recursos de imagen: icono adaptativo de cada flavor (`flutter_launcher_icons`), **banner de TV 320×180**.

---

## 14. PRUEBAS

| Nivel | Herramienta | Qué cubre |
|---|---|---|
| Unitarias | `test` | `VideoUrlResolver`, cálculo del %, formato de duraciones, mapeo de DTOs |
| Repositorios | `fake_cloud_firestore` | consultas, transacción de agregados, reordenamiento, `arrayUnion/Remove` |
| Estado | `bloc_test` | Cubits de catálogo y formularios, `PlayerBloc` (incluidos los errores) |
| Widgets | `flutter_test` | tarjetas, formularios, ErrorView, **navegación con teclado simulado** (`tester.sendKeyEvent(LogicalKeyboardKey.arrowRight)`) para el modo TV |
| Reglas | Emulador de Firebase + `@firebase/rules-unit-testing` | integrante lee el catálogo ✅ · cuenta sin `accounts` lee ❌ · cuenta desactivada lee ❌ · integrante escribe el progreso de otro ❌ · TV anónima sin aprobar lee el catálogo ❌ · TV aprobada escribe el progreso de quien la aprobó ✅ y el de otro ❌ · TV con la sesión vencida lee ❌ · integrante aprueba una TV con un nonce incorrecto ❌ · integrante aprueba una TV a nombre de otro ❌ · progreso con un campo extra ❌ · `positions` que no es mapa ❌ · integrante se escribe a sí mismo en `accounts` ❌ · integrante cambia su nombre ❌ · admin escribe un video con `day_number: 8` ❌ |
| Manual | dispositivos reales | teléfono de cada integrante de la familia + el Google TV: reproducir con WiFi lento, cortar el WiFi a mitad del video, salir y volver, control remoto en todas las pantallas |

Meta: lógica de `lib/core` con ≥ 80 % de cobertura; `flutter analyze` sin advertencias.

---

## 15. COMPILACIÓN, FIRMA, INSTALACIÓN Y ACTUALIZACIONES

### 15.1 Flavors (`android/app/build.gradle.kts`)
```kotlin
android {
    flavorDimensions += "app"
    productFlavors {
        create("user") {
            dimension = "app"
            applicationId = "com.ejerciciosapp.app"
            resValue("string", "app_name", "Ejercicios")
        }
        create("admin") {
            dimension = "app"
            applicationId = "com.ejerciciosapp.admin"
            resValue("string", "app_name", "Ejercicios Admin")
        }
    }
}
```
En el manifest principal: `android:label="@string/app_name"`.

### 15.2 Firma
- Crear **una** llave de firma y usarla siempre: Android solo instala una actualización encima de la app anterior si está firmada con la misma llave.
  ```powershell
  keytool -genkey -v -keystore $env:USERPROFILE\keys\ejercicios.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ejercicios
  ```
- `android/key.properties` (fuera de git) con las rutas y contraseñas, referenciado desde `build.gradle.kts`.
- Guardar una copia de la llave y sus contraseñas en otro lugar seguro. Si se pierde, hay que desinstalar y reinstalar la app en todos los dispositivos (el progreso no se pierde porque vive en Firestore, pero sí la sesión).

### 15.3 Compilar
```powershell
flutter build apk --release --flavor user  -t lib/main_user.dart
flutter build apk --release --flavor admin -t lib/main_admin.dart
# Resultado: build\app\outputs\flutter-apk\app-user-release.apk / app-admin-release.apk
```
Versionado en `pubspec.yaml`: `version: 1.0.0+1` → subir el número tras el `+` en cada entrega.

### 15.4 Instalar en teléfonos
- Pasar el APK (cable, Drive, WhatsApp o desde R2) → abrirlo → permitir "Instalar apps desconocidas" para esa app.
- Con cable y depuración USB: `adb install -r app-user-release.apk`.

### 15.5 Instalar en el Chromecast con Google TV
**0. Confirmar el modelo.** Si tu Chromecast tiene **control remoto propio y una pantalla de inicio de Google TV**, es un *Chromecast con Google TV* (4K o HD) y admite APKs. Si es el modelo antiguo sin control, al que solo se le envía contenido desde el teléfono, **no permite instalar apps** y habría que cambiar de plan (soporte de Google Cast desde el teléfono).
- Ver la versión: **Ajustes → Sistema → Información → Versión de Android TV OS**.
- Ver el espacio libre: **Ajustes → Sistema → Almacenamiento** (estos equipos traen ~8 GB; el APK ocupa ~30–40 MB).
- Ver la IP: **Ajustes → Red e Internet → tu red WiFi**.

**1. Activar las opciones de desarrollador:** Ajustes → Sistema → Información → pulsar **7 veces** "Compilación del SO de Android TV".

**2. Activar la depuración:** Ajustes → Sistema → Opciones de desarrollador → **Depuración por USB**. En Android TV 14 o superior, activar también **Depuración inalámbrica**.

**3. Instalar desde la PC** (en la misma red WiFi):
```powershell
# Android TV 12: con la depuración por USB activada basta con conectarse por red
adb connect 192.168.1.50:5555
# Android TV 14+: Depuración inalámbrica → "Vincular dispositivo con código"
adb pair 192.168.1.50:37123        # IP:puerto y código que muestra la TV
adb connect 192.168.1.50:41234     # IP:puerto que aparece en "Depuración inalámbrica"
adb devices                         # la primera vez, aceptar el aviso en la TV
adb install -r build\app\outputs\flutter-apk\app-user-release.apk
```
También sirve para depurar en vivo: `flutter run --flavor user -t lib/main_user.dart -d 192.168.1.50:5555`.

**4. Alternativa sin PC:** instalar **Downloader** (de AFTVnews) desde la tienda de Google TV, permitirle instalar apps (Ajustes → Apps → Seguridad y restricciones → Fuentes desconocidas), y abrir en ella la URL del APK en R2.

**5. Primer uso:** abrir "Ejercicios" desde la fila de apps; aparece el QR y se escanea desde la app del teléfono (Ajustes → Vincular TV).

### 15.6 Actualizaciones
- Desde la PC: `adb install -r` en cada dispositivo (conserva la sesión y los datos).
- Sin PC (opcional): subir el APK nuevo a R2 → actualizar la versión desde la Admin App (RF-A11) → en el teléfono, la User App muestra "Hay una nueva versión" y abre la descarga. En la TV, usar Downloader con la misma URL.

---

## 16. COSTOS

| Servicio | Uso estimado | Costo |
|---|---|---|
| Firebase Spark (Auth, Firestore, Crashlytics) | 4 usuarios: < 2 000 lecturas/día (límite gratuito: 50 000) y ≈ 1 500 escrituras/día por el avance de los videos (límite gratuito: 20 000) | **USD 0** |
| Cloudflare R2 | ~7 GB almacenados en resolución original (gratis hasta 10 GB); salida de datos gratis; lecturas muy por debajo de los 10 millones/mes gratis | **USD 0** |
| Google Play / Apple | No se usan | USD 0 |
| **Total** | | **USD 0 / mes** |

Si algún día el contenido pasa de 10 GB, R2 cobra alrededor de USD 0.015 por GB al mes por el excedente (verificar el precio vigente en Cloudflare).

---

## 17. ROADMAP POR SPRINTS (1 desarrollador, ~1 semana cada uno)

### Sprint 0 — Preparación
- [x] adb/emulador agregados al PATH; emuladores `Pixel8_API36` y `GoogleTV_API36` creados (27/10/2026).
  - ⚠️ No arrancan: la **virtualización (VT-x) está desactivada en la BIOS**. Para usarlos: activar "Intel Virtualization Technology" en la BIOS e instalar el *Android Emulator Hypervisor Driver* (SDK Manager → SDK Tools). Opcional: se puede probar directo en el Chromecast y los teléfonos.
- [x] rclone instalado (ffmpeg ya estaba). Scripts `tools/check_videos.ps1` y `tools/prepare_videos.ps1` probados con videos sintéticos (H.264, MPEG-4, HEVC 4K): conservan resolución y fps.
- [ ] Confirmar el modelo y la versión de Android TV del Chromecast (§15.5) y activar sus opciones de desarrollador.
- [ ] Prueba técnica de Google Cast: enviar el video de prueba de R2 desde un teléfono al Chromecast y elegir el paquete de Cast (ADR-015).
- [x] `flutter create`, flavors `user`/`admin` (con `manifestPlaceholders`, porque AGP actual desactiva `resValue`), manifest de TV con `LEANBACK_LAUNCHER` y banner provisional, canal nativo `isTv`, `very_good_analysis`, `git init` (sin commits).
- [x] Proyecto de Firebase **`ejercicios-app-fn07`** (plan Spark), Firestore en **`nam5`**, reglas provisionales que niegan todo.
- [ ] **(Consola)** Authentication → activar **Correo/contraseña** y **Anónimo**; crear tu cuenta de admin; probar que acepta `prueba@ejercicios.local`.
- [x] Apps Android registradas y `flutterfire configure` por flavor (`lib/firebase_options_user.dart`, `lib/firebase_options_admin.dart`, `google-services.json` por flavor). Firebase y Crashlytics se inicializan en `bootstrap.dart`.
- [ ] Cuenta de Cloudflare + bucket R2 público; preparar y subir **1 video de prueba**.
- **Listo cuando:** ambos flavors arrancan en el emulador conectados a Firebase y el video de prueba se reproduce desde R2 en un `VideoPlayer` mínimo **en el Chromecast real** (instalado por `adb`).

### Sprint 1 — Backend y núcleo
- [x] `firestore.rules` (admin UID `tHRziboLLwag3jZu6H7bqKELVlK2`) + índices + **26 pruebas de reglas** en el emulador (`rules_test/`, `npm run test:emulador`); **desplegadas** en `ejercicios-app-fn07` (28/10/2026).
- [x] `lib/core`: entidades (`domain/catalog.dart`, `domain/progress.dart`), mapeo Firestore, `Result`/`Failure`, `VideoUrlResolver`, `ResumePolicy` (§8.6) + pruebas.
- [x] `FirestoreCatalogRepository` y `FirestoreProgressRepository` (incluye `savePosition`/`clearPosition` con *merge*) + pruebas con `fake_cloud_firestore`.
- [x] `ui_kit`: tema, `FocusableCard` (foco con D-pad), `ErrorView`, `EmptyView` + pruebas de teclado. *(Shimmer se deja para el Sprint 3, cuando haya listas reales.)*
- [ ] Videos (§8.3): ✅ 21 videos copiados y renombrados (`Videos/{rodilla,cuello,hombro}/semana-1/`), ✅ `tools/catalogo.csv`, ⏳ compresión H.264 en curso con `tools/compress_videos.ps1` (misma resolución, ~41 % menos), ⏳ subir a R2 con rclone, ⏳ cargar el catálogo con `tools/seed.mjs` (probado en `--dry-run`).

### Sprint 2 — Admin App
- [ ] Login con guardia de admin.
- [ ] CRUD + reordenamiento de categorías, playlists y videos; "Probar video"; transacción de agregados; duplicar playlist.
- [ ] Integrantes: crear cuentas (instancia secundaria de Firebase), desactivar, restablecer acceso, ver/desvincular la TV.
- **Listo cuando:** cargas una semana completa de 7 días en menos de 10 minutos, los totales siempre cuadran, y una cuenta creada desde la app puede iniciar sesión mientras tu sesión de admin sigue abierta.

### Sprint 3 — User App en teléfono
- [ ] Splash, login, "¿Quién entrena hoy?", Home, detalle de playlist.
- [ ] Reproductor con controles propios, completado manual y al 90 %, siguiente ejercicio, wakelock, errores.
- [ ] **Guardar el avance y reanudar** (§8.6): guardado cada 10 s, al pausar, al salir y en segundo plano; reanudar 3 s antes con "Empezar de nuevo"; barras de avance en "Continuar" y en el detalle.
- [ ] Progreso por integrante, sin conexión incluido.
- 🎯 **Hito:** la familia puede usarla en los teléfonos.

### Sprint 4 — Google TV
- [ ] Manifest de TV + banner, detección de TV, layout de filas horizontales.
- [ ] Foco inicial, `FocusTraversalGroup`, `FocusableCard`, teclas del reproductor y multimedia.
- [ ] Pruebas de widgets con teclado simulado.
- [ ] Inicio de sesión por QR: pantalla del QR en la TV, escáner en el teléfono, reglas `tv_link_requests` / `tv_sessions` con sus pruebas.
- [ ] Google Cast desde el reproductor del teléfono, con progreso al 90 %.
- [ ] Probar en el emulador de TV y luego **en el Chromecast real**.
- **Listo cuando:** se puede usar todo con el control del Chromecast (solo D-pad, OK y Atrás), sin tocar nada más.

### Sprint 5 — Pulido e instalación
- [ ] Crear la llave de firma, compilar los APKs release.
- [ ] Instalar en los teléfonos de la familia y en el Google TV (§15.4–15.5).
- [ ] Prueba de uso real durante una semana; corregir lo que se reporte en Crashlytics.
- [ ] (Opcional) Aviso de actualización del APK.

```
S0 ─▶ S1 ─▶ S2 ─▶ S3 ─▶ S4 ─▶ S5
        └── codificación y subida de videos en paralelo ──┘
```

---

## 18. RIESGOS

| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| La navegación con el control remoto se siente torpe | Media | Alto | Sprint 4 dedicado; probar pronto en la TV real (el video de prueba del Sprint 0). |
| El Chromecast es lento | Media | Medio | Animaciones ligeras, portadas al tamaño mostrado, perfilar con `--profile`, desactivar Impeller si hay fallos de dibujo. |
| Los videos superan los 10 GB de R2 | Baja | Bajo | Pagar ~USD 0.015/GB del excedente (no se reduce la resolución). |
| Algún video original no se reproduce en el Chromecast (ej. 4K en el modelo HD, o un códec raro) | Media | Medio | El análisis de §8.3 lo marca; se recodifica solo el códec, sin cambiar la resolución. |
| El paquete de Flutter para Cast no está mantenido | Media | Medio | Prueba en el Sprint 0; plan B: puente nativo con el SDK de Cast. |
| La cámara de algún teléfono no lee bien el QR en la TV | Baja | Bajo | QR grande sobre fondo blanco; se puede añadir un código corto de respaldo. |
| Lentitud con la URL `r2.dev` | Baja | Medio | Conectar un dominio propio a R2. |
| Perder la llave de firma | Baja | Medio | Copia en otro lugar seguro (§15.2). |
| Alguien descubre una URL de video | Muy baja | Bajo | No se publican; las reglas protegen el catálogo. |
| Cambian las opciones de desarrollador de Google TV en una actualización | Baja | Bajo | Usar Downloader como alternativa. |

---

## 19. GUÍA DE ARRANQUE

### 19.1 Preparar el equipo
```powershell
flutter doctor --android-licenses
# PATH de usuario: %LOCALAPPDATA%\Android\sdk\platform-tools  y  %LOCALAPPDATA%\Android\sdk\emulator
winget install Rclone.Rclone       # ffmpeg ya está instalado
# Android Studio → Device Manager → Create device:
#   Phone → Pixel 8 → API 36 (Google Play)
#   TV    → Google TV 1080p → la imagen "Google TV" más reciente
flutter doctor -v
```

### 19.2 Crear el proyecto
```powershell
flutter create --org com.ejerciciosapp --project-name ejercicios_app --platforms android ejercicios_app
cd ejercicios_app
git init
flutter pub add firebase_core firebase_auth cloud_firestore firebase_crashlytics flutter_bloc go_router get_it freezed_annotation json_annotation intl cached_network_image connectivity_plus video_player wakelock_plus shared_preferences package_info_plus url_launcher qr_flutter mobile_scanner
flutter pub add --dev build_runner freezed json_serializable very_good_analysis bloc_test mocktail fake_cloud_firestore firebase_auth_mocks
```

### 19.3 Firebase
```powershell
firebase projects:create ejercicios-app-<sufijo>   # el ID debe ser único en todo Firebase
firebase init firestore emulators                   # en la carpeta del proyecto
flutterfire configure --project=ejercicios-app-<sufijo> --platforms=android `
  --android-package-name=com.ejerciciosapp.app `
  --out=lib/firebase_options_user.dart `
  --android-out=android/app/src/user/google-services.json
flutterfire configure --project=ejercicios-app-<sufijo> --platforms=android `
  --android-package-name=com.ejerciciosapp.admin `
  --out=lib/firebase_options_admin.dart `
  --android-out=android/app/src/admin/google-services.json
```

### 19.4 Día a día
```powershell
firebase emulators:start                                   # Auth + Firestore locales
flutter run --flavor user  -t lib/main_user.dart           # teléfono o emulador de TV (-d <id>)
flutter run --flavor admin -t lib/main_admin.dart
dart run build_runner watch -d
flutter test --coverage
firebase deploy --only firestore:rules,firestore:indexes
```

---

## 20. DEFINITION OF DONE Y PENDIENTES

### 20.1 Definition of Done
- [ ] `flutter analyze` sin advertencias y `dart format` aplicado.
- [ ] Pruebas de la lógica nueva en verde.
- [ ] Estados de carga, vacío, error y sin conexión implementados.
- [ ] Probado en un teléfono real **y** (si la pantalla existe en la User App) con el control remoto en la TV.
- [ ] Sin contraseñas ni llaves en git (`key.properties`, `*.jks` en `.gitignore`).

### 20.2 Decisiones confirmadas
- TV: Chromecast conectado a la TV → se asume **Chromecast con Google TV** (verificar en §15.5, paso 0).
- Videos: MP4 en una USB → flujo de §8.3.
- Cuentas: una por integrante, creadas por el admin con usuario y contraseña → §12.
- Almacenamiento: Cloudflare R2 → §8.1.
- TV: inicio de sesión por QR desde el teléfono → §12.6.
- Transmitir con Google Cast desde el teléfono → §11.7.
- Resolución: siempre la original, sin reescalar → §8.3–8.4.

### 20.3 Pendientes (se resuelven en el Sprint 0, sin bloquear el plan)
1. Versión de Android TV del Chromecast (12 o 14) y si es el modelo HD o 4K.
2. Resultado de `check_videos.ps1` sobre la USB: cuántos videos solo hay que reacomodar y cuántos recodificar, y el tamaño total real.
3. Los usuarios de cada integrante.
4. Qué paquete de Google Cast usar (prueba técnica del Sprint 0).
