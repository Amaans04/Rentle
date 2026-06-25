import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody, setAuthCookies } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import {
  verifyRefreshToken,
  generateAccessToken,
  generateRefreshToken,
  revokeRefreshToken,
} from '@/lib/jwt';
import { ValidationError } from '@/lib/validators';
import { getDb, COLLECTIONS } from '@/lib/firebase';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const body = await parseBody<{ refreshToken?: string }>(request);
    const refreshToken =
      body.refreshToken || request.cookies.get('refresh_token')?.value;

    if (!refreshToken) throw new ValidationError('Refresh token required');

    const payload = await verifyRefreshToken(refreshToken);
    await revokeRefreshToken(payload.jti!);

    const db = getDb();
    const userDoc = await db.collection(COLLECTIONS.USERS).doc(payload.uid).get();
    const userData = userDoc.data();
    const role = userData?.role ?? payload.role;
    const pgId = userData?.pgId ?? payload.pgId;

    const accessToken = generateAccessToken({ uid: payload.uid, role, pgId });
    const { token: newRefreshToken } = await generateRefreshToken({
      uid: payload.uid,
      role,
      pgId,
    });

    const response = jsonResponse({ token: accessToken, refreshToken: newRefreshToken });
    setAuthCookies(response, accessToken, newRefreshToken);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
