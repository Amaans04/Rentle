import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwner } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';

function getActivityTime(item: Record<string, unknown>): number {
  const paidAt = item.paidAt as { toMillis?: () => number } | undefined;
  const createdAt = item.createdAt as { toMillis?: () => number } | undefined;
  return paidAt?.toMillis?.() || createdAt?.toMillis?.() || 0;
}

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function GET(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwner(user);
    const db = getDb();

    const pgDoc = await db.collection(COLLECTIONS.PGS).doc(pgId).get();
    if (!pgDoc.exists) {
      return jsonResponse({ error: 'PG not found' }, 404);
    }

    const roomsSnapshot = await db
      .collection(COLLECTIONS.ROOMS)
      .where('pgId', '==', pgId)
      .get();

    const totalRooms = roomsSnapshot.size;
    let occupied = 0;
    let vacant = 0;

    roomsSnapshot.docs.forEach((doc) => {
      const status = doc.data().status;
      if (status === 'full' || status === 'partial') occupied++;
      if (status === 'vacant') vacant++;
    });

    const now = new Date();
    const month = now.getMonth() + 1;
    const year = now.getFullYear();

    const rentSnapshot = await db
      .collection(COLLECTIONS.RENT_RECORDS)
      .where('pgId', '==', pgId)
      .where('month', '==', month)
      .where('year', '==', year)
      .get();

    let rentCollected = 0;
    rentSnapshot.docs.forEach((doc) => {
      if (doc.data().status === 'paid') {
        rentCollected += doc.data().amount || 0;
      }
    });

    const recentRentSnapshot = await db
      .collection(COLLECTIONS.RENT_RECORDS)
      .where('pgId', '==', pgId)
      .where('status', '==', 'paid')
      .limit(25)
      .get();

    const recentComplaintsSnapshot = await db
      .collection(COLLECTIONS.COMPLAINTS)
      .where('pgId', '==', pgId)
      .limit(25)
      .get();

    const recentRent = recentRentSnapshot.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .sort((a, b) => getActivityTime(b) - getActivityTime(a))
      .slice(0, 5);

    const recentComplaints = recentComplaintsSnapshot.docs
      .map((d) => ({ id: d.id, ...d.data() }))
      .sort((a, b) => getActivityTime(b) - getActivityTime(a))
      .slice(0, 5);

    const activities = [
      ...recentRent.map((d) => ({
        type: 'payment' as const,
        ...d,
      })),
      ...recentComplaints.map((d) => ({
        type: 'complaint' as const,
        ...d,
      })),
    ]
      .sort((a, b) => getActivityTime(b) - getActivityTime(a))
      .slice(0, 5);

    const response = jsonResponse({
      pg: { id: pgDoc.id, ...pgDoc.data() },
      summary: { totalRooms, occupied, vacant, rentCollected },
      activities,
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
