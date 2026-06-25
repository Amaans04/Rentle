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

    const snapshot = await db
      .collection(COLLECTIONS.RENT_RECORDS)
      .where('pgId', '==', pgId)
      .where('tenantId', '==', user.uid)
      .limit(100)
      .get();

    const records = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .sort((a, b) => {
        const aData = a as { year?: number; month?: number };
        const bData = b as { year?: number; month?: number };
        const yearDiff = (bData.year ?? 0) - (aData.year ?? 0);
        if (yearDiff !== 0) return yearDiff;
        return (bData.month ?? 0) - (aData.month ?? 0);
      });
    const response = jsonResponse({ records });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
