import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { COLLECTIONS, getDb } from '@/lib/firebase';
import type { OtpRepository, OtpSession } from '@/services/auth/otp.service';

interface OtpSessionDoc {
  requestId: string;
  phone: string;
  role: string;
  otpHash: string;
  createdAt: Timestamp;
  expiresAt: Timestamp;
  attemptCount: number;
  maxAttempts: number;
  verified: boolean;
}

function docToSession(id: string, data: OtpSessionDoc): OtpSession {
  return {
    requestId: data.requestId,
    phone: id,
    role: data.role as OtpSession['role'],
    otpHash: data.otpHash,
    createdAt: data.createdAt.toDate(),
    expiresAt: data.expiresAt.toDate(),
    attemptCount: data.attemptCount,
    maxAttempts: data.maxAttempts,
    verified: data.verified,
  };
}

export class FirestoreOtpRepository implements OtpRepository {
  async saveSession(session: OtpSession): Promise<void> {
    const db = getDb();
    await db.collection(COLLECTIONS.OTP_SESSIONS).doc(session.phone).set({
      requestId: session.requestId,
      phone: session.phone,
      role: session.role,
      otpHash: session.otpHash,
      createdAt: Timestamp.fromDate(session.createdAt),
      expiresAt: Timestamp.fromDate(session.expiresAt),
      attemptCount: session.attemptCount,
      maxAttempts: session.maxAttempts,
      verified: session.verified,
    });
  }

  async getSessionByPhone(phone: string): Promise<OtpSession | null> {
    const db = getDb();
    const doc = await db.collection(COLLECTIONS.OTP_SESSIONS).doc(phone).get();
    if (!doc.exists) return null;
    return docToSession(doc.id, doc.data() as OtpSessionDoc);
  }

  async deleteSession(phone: string): Promise<void> {
    const db = getDb();
    await db.collection(COLLECTIONS.OTP_SESSIONS).doc(phone).delete();
  }

  async deleteExpiredSessions(before: Date): Promise<number> {
    const db = getDb();
    const snapshot = await db
      .collection(COLLECTIONS.OTP_SESSIONS)
      .where('expiresAt', '<', Timestamp.fromDate(before))
      .limit(100)
      .get();

    if (snapshot.empty) return 0;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    return snapshot.size;
  }

  async incrementAttemptCount(phone: string): Promise<number> {
    const db = getDb();
    const ref = db.collection(COLLECTIONS.OTP_SESSIONS).doc(phone);
    await ref.update({
      attemptCount: FieldValue.increment(1),
    });
    const updated = await ref.get();
    return (updated.data()?.attemptCount as number) ?? 0;
  }
}

let otpRepositoryInstance: FirestoreOtpRepository | null = null;

export function getOtpRepository(): FirestoreOtpRepository {
  if (!otpRepositoryInstance) {
    otpRepositoryInstance = new FirestoreOtpRepository();
  }
  return otpRepositoryInstance;
}
