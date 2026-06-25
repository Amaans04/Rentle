import { getDb, COLLECTIONS } from '@/lib/firebase';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

const MAX_REQUESTS = 3;
const WINDOW_MS = 10 * 60 * 1000;

interface RateLimitDoc {
  count: number;
  windowStart: Timestamp;
}

export async function checkOtpRateLimit(phone: string): Promise<boolean> {
  const db = getDb();
  const docRef = db.collection(COLLECTIONS.OTP_RATE_LIMIT).doc(phone);
  const now = Date.now();

  return db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);
    const data = doc.data() as RateLimitDoc | undefined;

    if (!data) {
      transaction.set(docRef, {
        count: 1,
        windowStart: Timestamp.fromMillis(now),
      });
      return true;
    }

    const windowStart = data.windowStart.toMillis();
    if (now - windowStart > WINDOW_MS) {
      transaction.set(docRef, {
        count: 1,
        windowStart: Timestamp.fromMillis(now),
      });
      return true;
    }

    if (data.count >= MAX_REQUESTS) {
      return false;
    }

    transaction.update(docRef, {
      count: FieldValue.increment(1),
    });
    return true;
  });
}
