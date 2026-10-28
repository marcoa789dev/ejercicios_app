// Pruebas de firestore.rules (PLAN_MAESTRO §7 y §14).
// Ejecutar desde rules_test/:  npm run test:emulador
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  collection,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const ADMIN = 'EVjSnowTIpQXQ1vuv3mBpWlxGvs1';
const NONCE = 'n'.repeat(40);
const HOUR = 60 * 60 * 1000;
const inHours = (h) => Timestamp.fromMillis(Date.now() + h * HOUR);

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ejercicios',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const seed = [
      ['accounts/mama-uid', { member_id: 'mama', username: 'mama', is_active: true }],
      ['accounts/papa-uid', { member_id: 'papa', username: 'papa', is_active: true }],
      ['accounts/tio-uid', { member_id: 'tio', username: 'tio', is_active: false }],
      ['members/mama', { display_name: 'Mamá', username: 'mama', is_active: true }],
      ['members/papa', { display_name: 'Papá', username: 'papa', is_active: true }],
      ['members/tio', { display_name: 'Tío', username: 'tio', is_active: false }],
      ['members/papa/progress/p1', { playlist_id: 'p1', completed_video_ids: [] }],
      ['categories/c1', { name: 'Rodilla', order: 1, is_active: true }],
      ['playlists/p1', { category_id: 'c1', title: 'Semana de la rodilla', is_active: true }],
      ['videos/v1', validVideo()],
      ['tv_link_requests/tv-nueva', { nonce: NONCE }],
      ['tv_sessions/tv-ok', { member_id: 'mama', nonce: NONCE, approved_by: 'mama-uid', expires_at: inHours(6) }],
      ['tv_sessions/tv-vencida', { member_id: 'mama', nonce: NONCE, approved_by: 'mama-uid', expires_at: inHours(-1) }],
      ['tv_sessions/tv-tio', { member_id: 'tio', nonce: NONCE, approved_by: 'tio-uid', expires_at: inHours(6) }],
    ];
    for (const [path, data] of seed) await setDoc(doc(db, path), data);
  });
});

function validVideo(overrides = {}) {
  return {
    playlist_id: 'p1',
    category_id: 'c1',
    title: 'Sesión del día 1',
    day_number: 1,
    order: 1,
    video_source: 'r2',
    stream_url: 'https://pub-x.r2.dev/rodilla/semana-1/dia1-01-sesion.mp4',
    duration_seconds: 3000,
    is_active: true,
    ...overrides,
  };
}

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('catálogo', () => {
  test('el admin lee y escribe un video válido', async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), 'videos/v1')));
    await assertSucceeds(setDoc(doc(as(ADMIN), 'videos/v2'), validVideo()));
  });

  test('el admin no puede guardar un video con día 8', async () => {
    await assertFails(setDoc(doc(as(ADMIN), 'videos/v2'), validVideo({ day_number: 8 })));
  });

  test('el admin no puede guardar un video con URL http', async () => {
    await assertFails(setDoc(doc(as(ADMIN), 'videos/v2'), validVideo({ stream_url: 'http://x.mp4' })));
  });

  test('un integrante activo lee el catálogo', async () => {
    await assertSucceeds(getDoc(doc(as('mama-uid'), 'categories/c1')));
    await assertSucceeds(getDocs(collection(as('mama-uid'), 'videos')));
  });

  test('un integrante no puede escribir el catálogo', async () => {
    await assertFails(setDoc(doc(as('mama-uid'), 'categories/c2'), { name: 'X' }));
    await assertFails(updateDoc(doc(as('mama-uid'), 'videos/v1'), { title: 'Otro' }));
  });

  test('sin sesión no se lee nada', async () => {
    await assertFails(getDoc(doc(anon(), 'categories/c1')));
  });

  test('una cuenta que no está en accounts no lee el catálogo', async () => {
    await assertFails(getDoc(doc(as('desconocido-uid'), 'categories/c1')));
  });

  test('una cuenta desactivada no lee el catálogo', async () => {
    await assertFails(getDoc(doc(as('tio-uid'), 'categories/c1')));
  });
});

describe('cuentas e integrantes', () => {
  test('un integrante lee su propia cuenta pero no la de otro', async () => {
    await assertSucceeds(getDoc(doc(as('mama-uid'), 'accounts/mama-uid')));
    await assertFails(getDoc(doc(as('mama-uid'), 'accounts/papa-uid')));
  });

  test('nadie salvo el admin escribe en accounts (ni sobre sí mismo)', async () => {
    await assertFails(setDoc(doc(as('desconocido-uid'), 'accounts/desconocido-uid'), { member_id: 'mama', is_active: true }));
    await assertFails(updateDoc(doc(as('tio-uid'), 'accounts/tio-uid'), { is_active: true }));
    await assertSucceeds(updateDoc(doc(as(ADMIN), 'accounts/tio-uid'), { is_active: true }));
  });

  test('un integrante actualiza su última playlist pero no su nombre', async () => {
    await assertSucceeds(updateDoc(doc(as('mama-uid'), 'members/mama'), { last_playlist_id: 'p1' }));
    await assertFails(updateDoc(doc(as('mama-uid'), 'members/mama'), { display_name: 'Otra' }));
    await assertFails(updateDoc(doc(as('mama-uid'), 'members/papa'), { last_playlist_id: 'p1' }));
  });
});

describe('progreso y avance de los videos', () => {
  const progress = (extra = {}) => ({
    playlist_id: 'p1',
    completed_video_ids: ['v1'],
    positions: { v2: 151 },
    last_video_id: 'v2',
    ...extra,
  });

  test('un integrante guarda su progreso con el avance de un video', async () => {
    await assertSucceeds(setDoc(doc(as('mama-uid'), 'members/mama/progress/p1'), progress()));
  });

  test('un integrante no lee ni escribe el progreso de otro', async () => {
    await assertFails(setDoc(doc(as('mama-uid'), 'members/papa/progress/p1'), progress()));
    await assertFails(getDoc(doc(as('mama-uid'), 'members/papa/progress/p1')));
  });

  test('el progreso rechaza campos extra, positions que no es mapa e id de playlist distinto', async () => {
    const ref = doc(as('mama-uid'), 'members/mama/progress/p1');
    await assertFails(setDoc(ref, progress({ hack: true })));
    await assertFails(setDoc(ref, progress({ positions: 'no-es-mapa' })));
    await assertFails(setDoc(ref, progress({ playlist_id: 'otra' })));
  });

  test('el admin puede leer el progreso de todos', async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), 'members/papa/progress/p1')));
  });
});

describe('TV vinculada por QR', () => {
  test('una TV anónima sin aprobar no lee el catálogo', async () => {
    await assertFails(getDoc(doc(as('tv-nueva'), 'categories/c1')));
  });

  test('la TV publica su propia solicitud con nonce largo, no la de otra', async () => {
    await assertSucceeds(setDoc(doc(as('tv-x'), 'tv_link_requests/tv-x'), { nonce: NONCE }));
    await assertFails(setDoc(doc(as('tv-x'), 'tv_link_requests/tv-x'), { nonce: 'corto' }));
    await assertFails(setDoc(doc(as('tv-x'), 'tv_link_requests/tv-y'), { nonce: NONCE }));
  });

  const session = (extra = {}) => ({
    member_id: 'mama',
    nonce: NONCE,
    approved_by: 'mama-uid',
    expires_at: inHours(12),
    ...extra,
  });

  test('un integrante aprueba la TV con el nonce correcto', async () => {
    await assertSucceeds(setDoc(doc(as('mama-uid'), 'tv_sessions/tv-nueva'), session()));
  });

  test('aprobar falla con nonce incorrecto, a nombre de otro o por más de 12 h', async () => {
    const ref = doc(as('mama-uid'), 'tv_sessions/tv-nueva');
    await assertFails(setDoc(ref, session({ nonce: 'x'.repeat(40) })));
    await assertFails(setDoc(ref, session({ member_id: 'papa' })));
    await assertFails(setDoc(ref, session({ expires_at: inHours(13) })));
  });

  test('una cuenta desconocida no puede aprobar una TV', async () => {
    await assertFails(setDoc(doc(as('desconocido-uid'), 'tv_sessions/tv-nueva'), session({ approved_by: 'desconocido-uid' })));
  });

  test('la TV aprobada lee el catálogo y escribe el progreso de quien la aprobó', async () => {
    await assertSucceeds(getDoc(doc(as('tv-ok'), 'categories/c1')));
    await assertSucceeds(setDoc(doc(as('tv-ok'), 'members/mama/progress/p1'), { playlist_id: 'p1', positions: { v1: 30 } }));
  });

  test('la TV aprobada no escribe el progreso de otro integrante', async () => {
    await assertFails(setDoc(doc(as('tv-ok'), 'members/papa/progress/p1'), { playlist_id: 'p1' }));
  });

  test('una TV con la sesión vencida no lee nada', async () => {
    await assertFails(getDoc(doc(as('tv-vencida'), 'categories/c1')));
  });

  test('una TV de un integrante desactivado no lee nada', async () => {
    await assertFails(getDoc(doc(as('tv-tio'), 'categories/c1')));
  });

  test('la TV puede salir (borrar su sesión)', async () => {
    await assertSucceeds(deleteDoc(doc(as('tv-ok'), 'tv_sessions/tv-ok')));
  });
});

describe('por defecto', () => {
  test('cualquier otra colección está cerrada, incluso para el admin', async () => {
    await assertFails(getDoc(doc(as(ADMIN), 'secretos/x')));
    await assertFails(setDoc(doc(as(ADMIN), 'secretos/x'), { a: 1 }));
  });
});
