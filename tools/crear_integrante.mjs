// Crea un integrante de la familia mientras la pantalla de Integrantes de la
// Admin App está pendiente (Sprint 2). Hace lo mismo que la app (§12.2):
// cuenta en Firebase Auth + members/{id} + accounts/{uid}.
//
// Uso (desde tools/):
//   node crear_integrante.mjs <usuario> "<Nombre visible>"
//   ej. node crear_integrante.mjs mama "Mamá"
//
// Pide la contraseña del admin y la del integrante nuevo (o ADMIN_PASSWORD /
// MEMBER_PASSWORD). Nada se guarda en archivos.
import { readFileSync } from 'node:fs';
import { stdin, stdout } from 'node:process';
import { createInterface } from 'node:readline/promises';

import { deleteApp, initializeApp } from 'firebase/app';
import { createUserWithEmailAndPassword, getAuth, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { collection, doc, getDocs, getFirestore, limit, query, serverTimestamp, where, writeBatch } from 'firebase/firestore';

const services = JSON.parse(readFileSync(new URL('../android/app/src/admin/google-services.json', import.meta.url), 'utf8'));
const FIREBASE = {
  apiKey: services.client[0].api_key[0].current_key,
  projectId: services.project_info.project_id,
  authDomain: `${services.project_info.project_id}.firebaseapp.com`,
};
const ADMIN_EMAIL = 'marcoa789.dev@gmail.com';
const PALETTE = ['#7E57C2', '#1E88E5', '#D81B60', '#F4511E', '#43A047', '#F9A825'];

const [username = '', displayName = ''] = process.argv.slice(2).map((s) => s.trim());
if (!/^[a-z0-9._-]{3,20}$/.test(username) || !displayName) {
  console.error('Uso: node crear_integrante.mjs <usuario> "<Nombre visible>"');
  console.error('El usuario: 3–20 caracteres, minúsculas, números, punto, guion y guion bajo.');
  process.exit(1);
}

const rl = createInterface({ input: stdin, output: stdout });
const adminPassword = process.env.ADMIN_PASSWORD ?? await rl.question(`Contraseña de ${ADMIN_EMAIL}: `);
const memberPassword = process.env.MEMBER_PASSWORD ?? await rl.question(`Contraseña para "${username}" (mín. 6): `);
rl.close();
if (memberPassword.length < 6) {
  console.error('La contraseña del integrante debe tener al menos 6 caracteres.');
  process.exit(1);
}

const app = initializeApp(FIREBASE);
await signInWithEmailAndPassword(getAuth(app), ADMIN_EMAIL, adminPassword);
const db = getFirestore(app);

const members = collection(db, 'members');
if (!(await getDocs(query(members, where('username', '==', username), limit(1)))).empty) {
  console.error(`El usuario "${username}" ya existe en members/.`);
  process.exit(1);
}
const order = (await getDocs(members)).size + 1;

// Instancia secundaria: crear la cuenta no cierra la sesión del admin
const creator = initializeApp(FIREBASE, 'account-creator');
let uid;
try {
  const auth = getAuth(creator);
  uid = (await createUserWithEmailAndPassword(auth, `${username}@ejercicios.local`, memberPassword)).user.uid;
  await signOut(auth);
} catch (e) {
  if (e.code === 'auth/email-already-in-use') {
    console.error(`Ya hay una cuenta ${username}@ejercicios.local en Firebase Auth. Bórrala en la consola o usa otro usuario.`);
    process.exit(1);
  }
  throw e;
} finally {
  await deleteApp(creator);
}

const ref = doc(members);
const now = serverTimestamp();
await writeBatch(db)
  .set(ref, {
    display_name: displayName,
    username,
    color_hex: PALETTE[(order - 1) % PALETTE.length],
    avatar: 'person',
    order,
    is_active: true,
    auth_uid: uid,
    created_at: now,
    updated_at: now,
  })
  .set(doc(db, 'accounts', uid), { member_id: ref.id, username, is_active: true })
  .commit();

console.log(`Listo: "${displayName}" puede entrar con el usuario "${username}".`);
process.exit(0);
