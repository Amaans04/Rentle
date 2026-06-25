import { initializeApp, getApps, cert, App } from 'firebase-admin/app';
import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { getAuth, Auth } from 'firebase-admin/auth';
import { getStorage, Storage } from 'firebase-admin/storage';
import { env } from './env';

let app: App;
let db: Firestore;
let auth: Auth;
let storage: Storage;

function initFirebase(): App {
  if (getApps().length > 0) {
    return getApps()[0];
  }

  return initializeApp({
    credential: cert({
      projectId: env.firebaseProjectId,
      clientEmail: env.firebaseClientEmail,
      privateKey: env.firebasePrivateKey,
    }),
    storageBucket: env.firebaseStorageBucket,
  });
}

export function getDb(): Firestore {
  if (!db) {
    app = initFirebase();
    db = getFirestore(app);
  }
  return db;
}

export function getFirebaseAuth(): Auth {
  if (!auth) {
    app = initFirebase();
    auth = getAuth(app);
  }
  return auth;
}

export function getFirebaseStorage(): Storage {
  if (!storage) {
    app = initFirebase();
    storage = getStorage(app);
  }
  return storage;
}

export const COLLECTIONS = {
  USERS: 'users',
  PGS: 'pgs',
  ROOMS: 'rooms',
  TENANTS: 'tenants',
  STAFF: 'staff',
  RENT_RECORDS: 'rentRecords',
  COMPLAINTS: 'complaints',
  NOTICES: 'notices',
  INVITES: 'invites',
  REFRESH_TOKENS: 'refreshTokens',
  OTP_RATE_LIMIT: 'otpRateLimit',
  OTP_SESSIONS: 'otpSessions',
  AUDIT_LOGS: 'auditLogs',
} as const;
