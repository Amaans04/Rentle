import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireTenant } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { ValidationError } from '@/lib/validators';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireTenant(user);
    const body = await parseBody<{ moveOutDate?: string }>(request);
    const db = getDb();

    const tenantRef = db.collection(COLLECTIONS.TENANTS).doc(user.uid);
    const tenantDoc = await tenantRef.get();

    if (!tenantDoc.exists || tenantDoc.data()?.pgId !== pgId) {
      throw new ValidationError('Tenant record not found');
    }

    let moveOutDate: Timestamp | null = null;
    if (body.moveOutDate) {
      const parsed = new Date(body.moveOutDate);
      if (Number.isNaN(parsed.getTime())) {
        throw new ValidationError('Invalid move-out date');
      }
      moveOutDate = Timestamp.fromDate(parsed);
    }

    await tenantRef.update({
      status: 'notice_given',
      noticeDate: FieldValue.serverTimestamp(),
      moveOutDate,
      updatedAt: FieldValue.serverTimestamp(),
    });

    const response = jsonResponse({ success: true });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
