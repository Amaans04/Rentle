import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody, setAuthCookies } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { getDb, getFirebaseAuth, COLLECTIONS } from '@/lib/firebase';
import { buildAuthResponse } from '@/lib/auth-helpers';
import { ValidationError } from '@/lib/validators';
import { FieldValue } from 'firebase-admin/firestore';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const body = await parseBody<{ idToken: string }>(request);
    if (!body.idToken) throw new ValidationError('idToken is required');

    const decoded = await getFirebaseAuth().verifyIdToken(body.idToken);
    const db = getDb();

    let userDoc = await db.collection(COLLECTIONS.USERS).doc(decoded.uid).get();
    let isNewUser = false;

    if (!userDoc.exists) {
      const emailSnapshot = decoded.email
        ? await db.collection(COLLECTIONS.USERS).where('email', '==', decoded.email).limit(1).get()
        : null;

      if (emailSnapshot && !emailSnapshot.empty) {
        userDoc = emailSnapshot.docs[0];
      } else {
        isNewUser = true;
        await db.collection(COLLECTIONS.USERS).doc(decoded.uid).set({
          uid: decoded.uid,
          name: decoded.name || '',
          phone: '',
          email: decoded.email || null,
          photoURL: decoded.picture || null,
          role: null,
          pgId: null,
          authProvider: 'google',
          onboarded: false,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          pushToken: null,
        });
        userDoc = await db.collection(COLLECTIONS.USERS).doc(decoded.uid).get();
      }
    }

    const userData = userDoc.data();
    const phone = userData?.phone || '';
    const authData = await buildAuthResponse(userDoc.id, isNewUser, phone || undefined);

    const response = jsonResponse({
      token: authData.token,
      refreshToken: authData.refreshToken,
      uid: authData.uid,
      isNewUser: authData.isNewUser,
      role: authData.role,
      pgId: authData.pgId,
      hasInvite: authData.hasInvite,
      inviteId: authData.inviteId,
    });

    setAuthCookies(response, authData.token, authData.refreshToken);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
