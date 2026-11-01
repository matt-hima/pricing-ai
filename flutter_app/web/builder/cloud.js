// Firebase：Google 登入、草稿雲端儲存、發佈網站、讀取預約。
import { FIREBASE, FIREBASE_SDK, COL_DRAFTS, COL_PUBLISHED } from "./config.js";

const { initializeApp } = await import(`${FIREBASE_SDK}/firebase-app.js`);
const authMod = await import(`${FIREBASE_SDK}/firebase-auth.js`);
const fs = await import(`${FIREBASE_SDK}/firebase-firestore.js`);

const app = initializeApp(FIREBASE, "site-builder");
export const auth = authMod.getAuth(app);
const db = fs.getFirestore(app);

export const onUser = (cb) => authMod.onAuthStateChanged(auth, cb);
export const signIn = () => authMod.signInWithPopup(auth, new authMod.GoogleAuthProvider());
export const signOut = () => authMod.signOut(auth);

/// 部署到使用者自己的 Firebase Hosting 需要 OAuth access token（firebase.hosting 權限）。
/// 透過 Firebase Auth 的 Google 登入順便要求該 scope，不必另外設定 OAuth client。
export async function hostingToken() {
  const p = new authMod.GoogleAuthProvider();
  p.addScope("https://www.googleapis.com/auth/firebase.hosting");
  p.setCustomParameters({ prompt: "consent" });
  const r = await authMod.signInWithPopup(auth, p);
  const cred = authMod.GoogleAuthProvider.credentialFromResult(r);
  if (!cred?.accessToken) throw new Error("Google did not return an access token.");
  return cred.accessToken;
}

const uid = () => {
  const u = auth.currentUser;
  if (!u) throw new Error("Please sign in first.");
  return u.uid;
};

export async function listMySites() {
  const q = fs.query(fs.collection(db, COL_DRAFTS), fs.where("ownerId", "==", uid()));
  const snap = await fs.getDocs(q);
  return snap.docs
    .map((d) => ({ slug: d.id, ...d.data() }))
    .sort((a, b) => (b.updatedAt?.toMillis?.() || 0) - (a.updatedAt?.toMillis?.() || 0));
}

export async function saveDraft(slug, name, projectData, lang = "en") {
  await fs.setDoc(fs.doc(db, COL_DRAFTS, slug), {
    ownerId: uid(),
    name,
    lang,
    project: JSON.stringify(projectData),
    updatedAt: fs.serverTimestamp(),
  });
}

export async function loadDraft(slug) {
  const s = await fs.getDoc(fs.doc(db, COL_DRAFTS, slug));
  if (!s.exists()) return null;
  const d = s.data();
  return { name: d.name, project: JSON.parse(d.project) };
}

export async function publish(slug, title, html) {
  await fs.setDoc(fs.doc(db, COL_PUBLISHED, slug), {
    ownerId: uid(),
    title,
    html,
    updatedAt: fs.serverTimestamp(),
  });
}

export async function unpublish(slug) {
  uid();
  await fs.deleteDoc(fs.doc(db, COL_PUBLISHED, slug));
}

export async function listBookings(slug) {
  uid();
  const q = fs.query(fs.collection(db, COL_PUBLISHED, slug, "bookings"), fs.orderBy("createdAt", "desc"), fs.limit(200));
  const snap = await fs.getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

export async function deleteBooking(slug, id) {
  await fs.deleteDoc(fs.doc(db, COL_PUBLISHED, slug, "bookings", id));
}
