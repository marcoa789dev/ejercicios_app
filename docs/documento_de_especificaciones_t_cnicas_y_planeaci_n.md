# ESPECIFICACIÓN TÉCNICA Y PLANEACIÓN DE PROYECTO: APP DE EJERCICIOS Y RUTINAS (ADMIN + USER)

**Versión:** 1.0  
**Fecha:** 27 de octubre de 2026  
**Propósito:** Especificación integral para la arquitectura, modelado de datos, configuración de infraestructura y desarrollo de un ecosistema de dos aplicaciones móviles (Admin y Usuario) centradas en el streaming de rutinas de ejercicio por categorías/semanas.

---

## 1. RESUMEN DEL PROYECTO Y OBJETIVOS

El proyecto consiste en una plataforma de distribución de contenido en video orientada a rutinas de ejercicios de rehabilitación y acondicionamiento físico (ej. "Semana de la Rodilla", "Semana del Hombro").

### Ecosistema de Software:
1. **App Administrador (Admin App):** Herramienta para gestión de contenido. Permite crear, editar, reordenar y eliminar categorías, rutinas/playlists y videos, además de gestionar las URLs directas de almacenamiento.
2. **App Usuario (User App):** Aplicación de consumo final. Presenta un catálogo estructurado por rutinas/semanas con reproductor de video nativo integrado, seguimiento de progreso ligero e interfaz limpia y responsiva.
3. **Backend Serverless (Firebase):** Base de datos Firestore para el catálogo, Firebase Authentication para la seguridad, y Firebase Storage (opcional/híbrido) o almacenamiento en la nube directo.

---

## 2. ARQUITECTURA GENERAL DEL SISTEMA

```
+-----------------------------------------------------------------------+
|                              ALMACENAMIENTO                           |
|  [Google Drive / Cloudflare R2 / AWS S3 / YouTube Unlisted]            |
|  (Archivos de Video MP4 / Streams)                                    |
+-----------------------------------------------------------------------+
                                   ^
                                   | (URLs Directas)
                                   v
+------------------------+      +------------------------+      +------------------------+
|       ADMIN APP        | ---> |   FIREBASE FIRESTORE   | <--- |        USER APP        |
| - Autenticación Admin  |      |   - Colección Rutinas  |      | - Catálogo de Rutinas  |
| - ABM de Rutinas       |      |   - Colección Videos   |      | - Reproductor Nativo   |
| - Gestor de URLs/Drive |      |   - Colección Usuarios |      | - Checklists Diario    |
+------------------------+      +------------------------+      +------------------------+
```

---

## 3. DECISIONES ARQUITECTÓNICAS Y TÉCNICAS (DECISION LOG)

A continuación se detallan las decisiones técnicas tomadas, junto con las alternativas evaluadas y la justificación correspondiente:

### [DECISIÓN 1] Framework de Desarrollo Móvil
* **Opción Selección:** **Flutter** (o React Native con Expo).
* **Justificación:** Permite compilar tanto la App de Usuario como la App de Administrador para Android e iOS a partir de una arquitectura de código compartido (o monorepo), manteniendo un rendimiento nativo en el reproductor de video.

### [DECISIÓN 2] Proveedor y Estrategia de Almacenamiento de Video
* **Opción Selección (Estrategia Híbrida):** 
  * *Opción A (Google Drive - Enlace directo transformado):* Para fase inicial/MVP a costo cero.
  * *Opción B (Cloudflare R2 / AWS S3 / YouTube Unlisted):* Para producción sin límites de consumo de ancho de banda.
* **Justificación:** La arquitectura del modelo de datos almacenará un `video_url` abstracto. Esto permite cambiar de proveedor de almacenamiento en cualquier momento sin alterar el código de la app. Para Google Drive, la Admin App transformará automáticamente las URLs tipo `/file/d/{ID}/view` a enlaces streaming directos.

### [DECISIÓN 3] Gestión de Estado y Capa de Datos
* **Opción Selección:** **BLoC / Provider (Flutter)** o **Zustand / TanStack Query (React Native)**.
* **Justificación:** Se requiere caché local para evitar consultas excesivas a Firestore, garantizando lectura fluida de las listas de reproducción incluso con conectividad inestable.

---

## 4. MODELO DE DATOS EN FIREBASE FIRESTORE

La base de datos seguirá una estructura no relacional (*NoSQL*) normalizada para optimizar lecturas.

### Colección: `categories`
Organiza las rutinas por zonas anatómicas o metas.
```json
{
  "id": "cat_rodilla",
  "name": "Rodilla",
  "description": "Rutinas de fortalecimiento y movilidad para rodilla",
  "order": 1,
  "created_at": "TIMESTAMP",
  "updated_at": "TIMESTAMP"
}
```

### Colección: `playlists` (Semanas / Rutinas)
Representa un bloque temático de ejercicios (ej. "Semana de la Rodilla").
```json
{
  "id": "playlist_rodilla_sem1",
  "category_id": "cat_rodilla",
  "title": "Semana 1: Movilidad y Desinflamación",
  "description": "Ejercicios de bajo impacto para primera fase.",
  "thumbnail_url": "https://...",
  "level": "Principiante", // [Principiante, Intermedio, Avanzado]
  "order": 1,
  "is_active": true,
  "total_videos": 5,
  "estimated_duration_minutes": 45,
  "created_at": "TIMESTAMP",
  "updated_at": "TIMESTAMP"
}
```

### Colección: `videos` (Subcolección de `playlists` o Colección independiente)
*Nota técnica: Se define como colección independiente `videos` con referencia a `playlist_id` para permitir consultas eficientes o reordenamiento flexible.*

```json
{
  "id": "video_001",
  "playlist_id": "playlist_rodilla_sem1",
  "title": "Día 1: Extensiones pasivas de cuádriceps",
  "description": "Mantener 10 segundos cada repetición. 3 series.",
  "day_number": 1, // Para ordenar por días de la semana
  "order": 1,
  "video_source": "google_drive", // ["google_drive", "direct_mp4", "youtube"]
  "raw_url": "https://drive.google.com/file/d/1A2B3C4D5E/view?usp=sharing",
  "direct_stream_url": "https://drive.google.com/uc?export=download&id=1A2B3C4D5E",
  "duration_seconds": 420,
  "thumbnail_url": "https://...",
  "created_at": "TIMESTAMP"
}
```

### Colección: `users`
```json
{
  "uid": "firebase_auth_uid",
  "email": "usuario@example.com",
  "role": "user", // ["admin", "user"]
  "completed_videos": ["video_001", "video_002"],
  "created_at": "TIMESTAMP"
}
```

---

## 5. ESPECIFICACIÓN DETALLADA: APLICACIÓN ADMINISTRADOR (ADMIN APP)

### 5.1 Pantallas y Módulos
1. **Autenticación (Login):**
   * Control de acceso estricto mediante Firebase Auth y validación de `role == 'admin'` en Firestore.
2. **Dashboard / Lista de Categorías y Playlists:**
   * Lista visual de las categorías existentes.
   * Botón de ordenamiento mediante *Drag and Drop*.
3. **Creador / Editor de Playlist (Semana):**
   * Campos: Título, Categoría, Descripción, Imagen de Portada (URL o Subida a Storage), Nivel de Dificultad.
4. **Gestor de Videos de la Playlist:**
   * Formulario para añadir videos:
     * Campo para pegar URL (con conversor automático de enlaces de Google Drive).
     * Selector de día de la semana (Día 1 a Día 7).
     * Campo de título y descripción técnica del ejercicio.
   * Reordenamiento dinámico de los videos dentro de la semana.

### 5.2 Algoritmo de Conversión de URLs de Google Drive (Requisito Clave)
La Admin App debe incluir un módulo utilitario que procese el enlace pegado por el usuario:
```typescript
function transformDriveUrl(url: string): { directUrl: string; source: string } {
  const driveRegex = /\/d\/([a-zA-Z0-9_-]+)/;
  const match = url.match(driveRegex);
  
  if (match && match[1]) {
    const fileId = match[1];
    return {
      directUrl: `https://drive.google.com/uc?export=download&id=${fileId}`,
      source: "google_drive"
    };
  }
  
  return {
    directUrl: url,
    source: "direct_mp4"
  };
}
```

---

## 6. ESPECIFICACIÓN DETALLADA: APLICACIÓN USUARIOS (USER APP)

### 6.1 Pantallas y Flujo de Navegación
1. **Home / Catálogo de Rutinas:**
   * Categorías mostradas como pestañas o carruseles (Ej: Rodilla, Hombro, Espalda).
   * Tarjetas (*Cards*) visuales para cada rutina (Ej: "Semana de la Rodilla"). Muestra barra de progreso (% completado).
2. **Vista de Playlist (Detalle de la Semana):**
   * Encabezado con detalles, objetivo de la semana y duración total.
   * Lista ordenada por días (Día 1, Día 2, etc.) con indicador de estado (Pendiente / Completado).
3. **Reproductor de Video Nativo (Player Screen):**
   * Reproductor de video integrado (usando `video_player` / `chewie` en Flutter o `expo-av` / `react-native-video`).
   * Controles de reproducción: Play/Pausa, adelantar/atrasar 10s, velocidad de reproducción (0.75x, 1x, 1.25x).
   * Sección desplegable debajo del video con las instrucciones del ejercicio.
   * Botón prominente: **"Marcar como completado"**.

---

## 7. REGLAS DE SEGURIDAD FIRESTORE (FIREBASE SECURITY RULES)

Para garantizar la integridad y proteger los datos de la aplicación:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Función auxiliar para verificar si el usuario es Admin
    function isAdmin() {
      return request.auth != null && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == "admin";
    }

    // Reglas para el catálogo (Categorías, Playlists, Videos)
    match /categories/{category} {
      allow read: if true; // Cualquier usuario autenticado o anónimo puede leer
      allow write: if isAdmin(); // Solo el Admin puede crear/editar/eliminar
    }
    
    match /playlists/{playlist} {
      allow read: if true;
      allow write: if isAdmin();
    }
    
    match /videos/{video} {
      allow read: if true;
      allow write: if isAdmin();
    }

    // Reglas para perfil de usuario
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 8. PLAN DE IMPLEMENTACIÓN POR FASES (ROADMAP)

### Fase 1: Configuración de Infraestructura y Base de Datos (Semana 1)
* [ ] Crear proyecto en consola de Firebase.
* [ ] Configurar Firestore Database y habilitar Firebase Auth (Email/Password o Anónimo).
* [ ] Desplegar las reglas de seguridad iniciales.

### Fase 2: Desarrollo de la Admin App (Semana 2)
* [ ] Construir la interfaz de autenticación del administrador.
* [ ] Implementar el CRUD de Categorías y Playlists ("Semanas").
* [ ] Implementar el módulo de carga de videos con el transformador automático de URLs de Google Drive.
* [ ] Pruebas de persistencia e integración con Firestore.

### Fase 3: Desarrollo de la User App (Semana 3)
* [ ] Diseñar el Home con la lista de categorías y rutinas.
* [ ] Integrar el reproductor de video nativo configurado para consumo HLS/MP4 desde la red.
* [ ] Implementar la lógica de marcado de videos completados y persistencia local/remota del progreso.

### Fase 4: Pruebas de Streaming, Optimización y Pulido (Semana 4)
* [ ] Validar latencias de carga de videos desde Google Drive / CDN alternativas.
* [ ] Implementar pantalla de manejo de errores de reproducción (ej. enlace caído o límite de ancho de banda excedido).
* [ ] Pruebas en dispositivos físicos Android e iOS.

---

## 9. INSTRUCCIONES PROMPT PARA AGENTES/IA DE CÓDIGO

*(Utilizar las siguientes directrices al solicitar generación de código fuente a modelos LLM)*

1. **Estilo de código:** Modular, aplicando principios SOLID y separación estricta entre la capa de interfaz de usuario (UI), lógica de negocio (State Management) y servicios de datos (Repository Pattern).
2. **Manejo de Errores de Video:** Asegurar que el reproductor capture excepciones de red o timeout e informe al usuario mediante un widget decorativo con un botón de "Reintentar".
3. **Rendimiento:** Implementar almacenamiento en caché para imágenes de portada e implementar paginación o *lazy loading* en el catálogo principal para minimizar el uso de cuota de lectura en Firestore.