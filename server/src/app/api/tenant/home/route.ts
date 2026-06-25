import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireTenant } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function GET(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireTenant(user);
    const db = getDb();

    const userDoc = await db.collection(COLLECTIONS.USERS).doc(user.uid).get();
    const pgDoc = await db.collection(COLLECTIONS.PGS).doc(pgId).get();
    const tenantDoc = await db.collection(COLLECTIONS.TENANTS).doc(user.uid).get();

    let room = null;
    if (tenantDoc.exists) {
      const roomId = tenantDoc.data()?.roomId;
      if (roomId) {
        const roomDoc = await db.collection(COLLECTIONS.ROOMS).doc(roomId).get();
        if (roomDoc.exists) room = { id: roomDoc.id, ...roomDoc.data() };
      }
    }

    const now = new Date();
    const rentSnapshot = await db
      .collection(COLLECTIONS.RENT_RECORDS)
      .where('pgId', '==', pgId)
      .where('tenantId', '==', user.uid)
      .where('month', '==', now.getMonth() + 1)
      .where('year', '==', now.getFullYear())
      .limit(1)
      .get();

    const currentRent = rentSnapshot.empty ? null : rentSnapshot.docs[0].data();

    const noticesSnapshot = await db
      .collection(COLLECTIONS.NOTICES)
      .where('pgId', '==', pgId)
      .limit(50)
      .get();

    const notices = noticesSnapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() } as {
        id: string;
        targetRole?: string;
        createdAt?: { toMillis?: () => number };
      }))
      .filter((n) => n.targetRole === 'all' || n.targetRole === 'tenant')
      .sort((a, b) => {
        const aTime = a.createdAt?.toMillis?.() ?? 0;
        const bTime = b.createdAt?.toMillis?.() ?? 0;
        return bTime - aTime;
      })
      .slice(0, 3);

    const response = jsonResponse({
      user: { id: userDoc.id, ...userDoc.data() },
      pg: pgDoc.exists ? { id: pgDoc.id, ...pgDoc.data() } : null,
      room,
      currentRent,
      notices,
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
