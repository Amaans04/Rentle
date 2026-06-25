import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { getDb, COLLECTIONS } from './firebase';
import { env } from './env';
import { FieldValue } from 'firebase-admin/firestore';

export type UserRole = 'owner' | 'manager' | 'tenant' | null;

export interface TokenPayload {
  uid: string;
  role: UserRole;
  pgId: string | null;
  jti?: string;
  type?: 'access' | 'refresh';
}

const ACCESS_EXPIRY = '15m';
const REFRESH_EXPIRY = '7d';

export function generateAccessToken(payload: Omit<TokenPayload, 'jti' | 'type'>): string {
  return jwt.sign(
    { ...payload, type: 'access' },
    env.jwtSecret,
    { expiresIn: ACCESS_EXPIRY }
  );
}

export async function generateRefreshToken(
  payload: Omit<TokenPayload, 'jti' | 'type'>
): Promise<{ token: string; jti: string }> {
  const jti = uuidv4();
  const token = jwt.sign(
    { ...payload, jti, type: 'refresh' },
    env.jwtRefreshSecret,
    { expiresIn: REFRESH_EXPIRY }
  );

  await getDb().collection(COLLECTIONS.REFRESH_TOKENS).doc(jti).set({
    uid: payload.uid,
    revoked: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { token, jti };
}

export function verifyAccessToken(token: string): TokenPayload {
  const decoded = jwt.verify(token, env.jwtSecret) as TokenPayload;
  if (decoded.type !== 'access') {
    throw new Error('Invalid token type');
  }
  return decoded;
}

export async function verifyRefreshToken(token: string): Promise<TokenPayload> {
  const decoded = jwt.verify(token, env.jwtRefreshSecret) as TokenPayload;
  if (decoded.type !== 'refresh' || !decoded.jti) {
    throw new Error('Invalid refresh token');
  }

  const doc = await getDb().collection(COLLECTIONS.REFRESH_TOKENS).doc(decoded.jti).get();
  if (!doc.exists || doc.data()?.revoked) {
    throw new Error('Refresh token revoked');
  }

  return decoded;
}

export async function revokeRefreshToken(jti: string): Promise<void> {
  await getDb().collection(COLLECTIONS.REFRESH_TOKENS).doc(jti).update({
    revoked: true,
  });
}

export function extractBearerToken(authHeader: string | null): string | null {
  if (!authHeader?.startsWith('Bearer ')) return null;
  return authHeader.slice(7);
}
