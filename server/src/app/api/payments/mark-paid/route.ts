import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireTenant } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, ValidationError } from '@/lib/validators';
import { FieldValue } from 'firebase-admin/firestore';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireTenant(user);
    const body = await parseBody<{ recordId: string; method: string }>(request);

    const recordId = requireString(body.recordId, 'recordId');
    const method = requireString(body.method, 'method');

    if (!['upi', 'cash', 'card'].includes(method)) {
      throw new ValidationError('Invalid payment method');
    }

    const db = getDb();
    const recordDoc = await db.collection(COLLECTIONS.RENT_RECORDS).doc(recordId).get();

    if (!recordDoc.exists) throw new ValidationError('Record not found');

    const data = recordDoc.data()!;
    if (data.pgId !== pgId || data.tenantId !== user.uid) {
      throw new ValidationError('Forbidden');
    }

    await recordDoc.ref.update({
      status: 'paid',
      paymentMethod: method,
      paidAt: FieldValue.serverTimestamp(),
    });

    const response = jsonResponse({ success: true });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
