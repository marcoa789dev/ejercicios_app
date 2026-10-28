// Carga el catálogo de tools/catalogo.csv en Firestore (PLAN_MAESTRO §8.3, paso 7).
//
// Uso (desde tools/):
//   npm install
//   node seed.mjs --dry-run                 # muestra lo que haría, sin escribir
//   node seed.mjs --solo-subidos            # solo los videos que ya están en R2
//   node seed.mjs                           # todo el CSV
//
// Inicia sesión como el admin con email y contraseña (sin cuenta de servicio).
// La contraseña se pide por consola; también puede venir en ADMIN_PASSWORD.
// Los IDs son deterministas (ej. "rodilla", "rodilla-s1", "rodilla-s1-d1-01"),
// así que volver a ejecutarlo actualiza en lugar de duplicar.
import { readFileSync } from 'node:fs';
import { stdin, stdout } from 'node:process';
import { createInterface } from 'node:readline/promises';

import { initializeApp } from 'firebase/app';
import { getAuth, signInWithEmailAndPassword } from 'firebase/auth';
import { doc, getFirestore, serverTimestamp, writeBatch } from 'firebase/firestore';

// La configuración sale del google-services.json del flavor admin (generado por flutterfire).
const services = JSON.parse(readFileSync(new URL('../android/app/src/admin/google-services.json', import.meta.url), 'utf8'));
const FIREBASE = {
  apiKey: services.client[0].api_key[0].current_key,
  projectId: services.project_info.project_id,
  authDomain: `${services.project_info.project_id}.firebaseapp.com`,
};
const ADMIN_EMAIL = 'marcoa789.dev@gmail.com';
const R2_BASE = 'https://pub-39ad206303ce4d2fb6c50358e51f7725.r2.dev';
const CATEGORY_ORDER = ['Rodilla', 'Hombro', 'Cuello'];

const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');
const onlyUploaded = args.has('--solo-subidos');

// ---------- CSV (comillas dobles, comas dentro de comillas) ----------
function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (c === '"') quoted = false;
      else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(cell); cell = '';
      if (row.some((v) => v !== '')) rows.push(row);
      row = [];
    } else cell += c;
  }
  if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
  const [header, ...data] = rows;
  return data.map((r) => Object.fromEntries(header.map((h, i) => [h.trim(), (r[i] ?? '').trim()])));
}

const slug = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
const intOrNull = (s) => (s === '' ? null : Number.parseInt(s, 10));

async function isUploaded(path) {
  const res = await fetch(`${R2_BASE}/${path}`, { method: 'HEAD' });
  return res.ok;
}

// ---------- Construir el catálogo ----------
const rows = parseCsv(readFileSync(new URL('./catalogo.csv', import.meta.url), 'utf8').replace(/^﻿/, ''));
const categories = new Map();
const playlists = new Map();
const videos = [];

for (const r of rows) {
  if (onlyUploaded && !(await isUploaded(r.archivo))) continue;
  const catId = slug(r.categoria);
  const week = Number.parseInt(r.semana, 10) || 1;
  const plId = `${catId}-s${week}`;
  const day = Number.parseInt(r.dia, 10);
  const order = Number.parseInt(r.orden, 10) || 1;
  const order0 = CATEGORY_ORDER.indexOf(r.categoria);

  categories.set(catId, {
    name: r.categoria,
    description: '',
    order: order0 === -1 ? CATEGORY_ORDER.length + categories.size : order0 + 1,
    is_active: true,
  });

  const pl = playlists.get(plId) ?? {
    category_id: catId,
    title: r.titulo_semana,
    description: '',
    goal: '',
    level: r.nivel || 'beginner',
    week_number: week,
    order: week,
    is_active: true,
    thumbnail_url: `${R2_BASE}/${r.archivo.replace(/\.mp4$/, '.webp')}`,
    _days: new Set(),
    total_videos: 0,
    total_duration_seconds: 0,
  };
  pl._days.add(day);
  pl.total_videos += 1;
  pl.total_duration_seconds += Number.parseInt(r.duracion_s, 10) || 0;
  playlists.set(plId, pl);

  videos.push({
    id: `${plId}-d${day}-${String(order).padStart(2, '0')}`,
    data: {
      playlist_id: plId,
      category_id: catId,
      title: r.titulo,
      instructions: r.instrucciones,
      sets: intOrNull(r.series),
      reps: intOrNull(r.reps),
      day_number: day,
      order,
      video_source: 'r2',
      raw_url: `${R2_BASE}/${r.archivo}`,
      stream_url: `${R2_BASE}/${r.archivo}`,
      duration_seconds: Number.parseInt(r.duracion_s, 10) || 0,
      thumbnail_url: `${R2_BASE}/${r.archivo.replace(/\.mp4$/, '.webp')}`,
      is_active: true,
    },
  });
}

console.log(`Categorías: ${categories.size} · playlists: ${playlists.size} · videos: ${videos.length}`);
for (const [id, p] of playlists) {
  console.log(`  ${id}: ${p.title} · ${p.total_videos} videos · ${(p.total_duration_seconds / 3600).toFixed(1)} h`);
}
if (dryRun) {
  console.log('--dry-run: no se escribió nada.');
  process.exit(0);
}
if (videos.length === 0) {
  console.log('No hay videos que cargar.');
  process.exit(0);
}

// ---------- Escribir ----------
let password = process.env.ADMIN_PASSWORD;
if (!password) {
  const rl = createInterface({ input: stdin, output: stdout });
  password = await rl.question(`Contraseña de ${ADMIN_EMAIL}: `);
  rl.close();
}

const app = initializeApp(FIREBASE);
await signInWithEmailAndPassword(getAuth(app), ADMIN_EMAIL, password);
const db = getFirestore(app);

const batch = writeBatch(db);
const now = serverTimestamp();
for (const [id, c] of categories) {
  batch.set(doc(db, 'categories', id), { ...c, updated_at: now }, { merge: true });
}
for (const [id, { _days, ...p }] of playlists) {
  batch.set(doc(db, 'playlists', id), { ...p, days_count: _days.size, updated_at: now }, { merge: true });
}
for (const v of videos) {
  batch.set(doc(db, 'videos', v.id), { ...v.data, updated_at: now }, { merge: true });
}
await batch.commit();
console.log('Catálogo cargado en Firestore.');
process.exit(0);
