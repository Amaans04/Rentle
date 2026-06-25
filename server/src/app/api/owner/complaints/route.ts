import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwnerOrManager } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function GET(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwnerOrManager(user);
    const db = getDb();

    const snapshot = await db
      .collection(COLLECTIONS.COMPLAINTS)
      .where('pgId', '==', pgId)
      .limit(100)
      .get();

    const sorted = snapshot.docs
      .map((doc) => ({ id: doc.id, ref: doc, data: doc.data() }))
      .sort((a, b) => {
        const aTime =
          (a.data.createdAt as { toMillis?: () => number })?.toMillis?.() ?? 0;
        const bTime =
          (b.data.createdAt as { toMillis?: () => number })?.toMillis?.() ?? 0;
        return bTime - aTime;
      });

    const complaints = await Promise.all(
      sorted.map(async ({ id, data }) => {
        const tenantDoc = await db.collection(COLLECTIONS.USERS).doc(data.tenantId).get();
        const roomDoc = data.roomId
          ? await db.collection(COLLECTIONS.ROOMS).doc(data.roomId).get()
          : null;
        return {
          id,
          ...data,
          tenantName: tenantDoc.data()?.name || 'Unknown',
          roomNumber: roomDoc?.data()?.roomNumber || '',
        };
      })
    );

    const response = jsonResponse({ complaints });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
