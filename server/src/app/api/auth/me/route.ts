import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function GET(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const db = getDb();
    const userDoc = await db.collection(COLLECTIONS.USERS).doc(user.uid).get();

    if (!userDoc.exists) {
      return jsonResponse({ error: 'User not found' }, 404);
    }

    const userData = userDoc.data()!;
    let pg = null;

    if (userData.pgId) {
      const pgDoc = await db.collection(COLLECTIONS.PGS).doc(userData.pgId).get();
      if (pgDoc.exists) {
        pg = { id: pgDoc.id, ...pgDoc.data() };
      }
    }

    const response = jsonResponse({ user: { id: userDoc.id, ...userData }, pg });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
