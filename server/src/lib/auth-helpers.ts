import { getDb, COLLECTIONS } from '@/lib/firebase';
import { generateAccessToken, generateRefreshToken } from '@/lib/jwt';
import { sanitizePhone } from '@/lib/validators';
import { Timestamp } from 'firebase-admin/firestore';

export interface AuthResponse {
  token: string;
  refreshToken: string;
  uid: string;
  isNewUser: boolean;
  role: string | null;
  pgId: string | null;
  hasInvite: boolean;
  inviteId: string | null;
}

export async function findPendingInvite(phone: string) {
  const db = getDb();
  const now = Timestamp.now();
  const snapshot = await db
    .collection(COLLECTIONS.INVITES)
    .where('phone', '==', sanitizePhone(phone))
    .where('status', '==', 'pending')
    .get();

  const valid = snapshot.docs.find((doc) => {
    const expiresAt = doc.data().expiresAt as Timestamp;
    return expiresAt.toMillis() > now.toMillis();
  });

  if (!valid) return null;
  return { id: valid.id, ...valid.data() };
}

export async function buildAuthResponse(
  uid: string,
  isNewUser: boolean,
  phone?: string
): Promise<AuthResponse> {
  const db = getDb();
  const userDoc = await db.collection(COLLECTIONS.USERS).doc(uid).get();
  const userData = userDoc.data();
  const role = userData?.role ?? null;
  const pgId = userData?.pgId ?? null;

  let hasInvite = false;
  let inviteId: string | null = null;

  if (phone) {
    const invite = await findPendingInvite(phone);
    if (invite) {
      hasInvite = true;
      inviteId = invite.id;
    }
  }

  const accessToken = generateAccessToken({ uid, role, pgId });
  const { token: refreshToken } = await generateRefreshToken({ uid, role, pgId });

  return {
    token: accessToken,
    refreshToken,
    uid,
    isNewUser,
    role,
    pgId,
    hasInvite,
    inviteId,
  };
}
