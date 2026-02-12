import { initializeApp, getApps, getApp, type FirebaseApp } from "firebase/app"
import { getAuth, type Auth } from "firebase/auth"
import { getFirestore, type Firestore } from "firebase/firestore"
import { getStorage, type FirebaseStorage } from "firebase/storage"

// Firebase configuration - use environment variables
const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
}

function getFirebaseApp(): FirebaseApp {
  if (getApps().length > 0) return getApp()

  if (!firebaseConfig.apiKey) {
    throw new Error("Firebase API key is missing. Set NEXT_PUBLIC_FIREBASE_API_KEY.")
  }

  return initializeApp(firebaseConfig)
}

// Lazy initialization — services are only created when first accessed at runtime,
// not during Next.js static page generation at build time.
let _app: FirebaseApp | null = null
let _auth: Auth | null = null
let _db: Firestore | null = null
let _storage: FirebaseStorage | null = null

function ensureApp(): FirebaseApp {
  if (!_app) _app = getFirebaseApp()
  return _app
}

export const auth = new Proxy({} as Auth, {
  get(_, prop) {
    if (!_auth) _auth = getAuth(ensureApp())
    return Reflect.get(_auth, prop)
  },
})

export const db = new Proxy({} as Firestore, {
  get(_, prop) {
    if (!_db) _db = getFirestore(ensureApp())
    return Reflect.get(_db, prop)
  },
})

export const storage = new Proxy({} as FirebaseStorage, {
  get(_, prop) {
    if (!_storage) _storage = getStorage(ensureApp())
    return Reflect.get(_storage, prop)
  },
})

export default new Proxy({} as FirebaseApp, {
  get(_, prop) {
    return Reflect.get(ensureApp(), prop)
  },
})
