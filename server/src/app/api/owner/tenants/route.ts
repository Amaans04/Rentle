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

    const tenantsSnapshot = await db
      .collection(COLLECTIONS.TENANTS)
      .where('pgId', '==', pgId)
      .where('status', '==', 'active')
      .get();

    const tenants = await Promise.all(
      tenantsSnapshot.docs.map(async (tenantDoc) => {
        const tenantData = tenantDoc.data();
        const userDoc = await db.collection(COLLECTIONS.USERS).doc(tenantData.uid).get();
        const roomDoc = tenantData.roomId
          ? await db.collection(COLLECTIONS.ROOMS).doc(tenantData.roomId).get()
          : null;

        const now = new Date();
        const rentSnapshot = await db
          .collection(COLLECTIONS.RENT_RECORDS)
          .where('pgId', '==', pgId)
          .where('tenantId', '==', tenantData.uid)
          .where('month', '==', now.getMonth() + 1)
          .where('year', '==', now.getFullYear())
          .limit(1)
          .get();

        const rentStatus = rentSnapshot.empty ? 'unpaid' : rentSnapshot.docs[0].data().status;

        return {
          id: tenantDoc.id,
          ...tenantData,
          name: userDoc.data()?.name || 'Unknown',
          phone: userDoc.data()?.phone || '',
          photoURL: userDoc.data()?.photoURL || null,
          roomNumber: roomDoc?.data()?.roomNumber || '',
          rentStatus,
        };
      })
    );

    const response = jsonResponse({ tenants });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
