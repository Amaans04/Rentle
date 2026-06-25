import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireTenant } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, validateComplaintType, ValidationError } from '@/lib/validators';
import { FieldValue } from 'firebase-admin/firestore';
import { v4 as uuidv4 } from 'uuid';

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
      .collection(COLLECTIONS.COMPLAINTS)
      .where('pgId', '==', pgId)
      .where('tenantId', '==', user.uid)
      .limit(100)
      .get();

    const complaints = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .sort((a, b) => {
        const aTime =
          ((a as { createdAt?: { toMillis?: () => number } }).createdAt)
            ?.toMillis?.() ?? 0;
        const bTime =
          ((b as { createdAt?: { toMillis?: () => number } }).createdAt)
            ?.toMillis?.() ?? 0;
        return bTime - aTime;
      });
    const response = jsonResponse({ complaints });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireTenant(user);
    const body = await parseBody<Record<string, unknown>>(request);

    const type = requireString(body.type, 'type');
    const description = requireString(body.description, 'description');
    validateComplaintType(type);

    const db = getDb();
    const tenantDoc = await db.collection(COLLECTIONS.TENANTS).doc(user.uid).get();
    if (!tenantDoc.exists || tenantDoc.data()?.pgId !== pgId) {
      throw new ValidationError('Tenant record not found');
    }

    const complaintId = uuidv4();
    await db.collection(COLLECTIONS.COMPLAINTS).doc(complaintId).set({
      complaintId,
      pgId,
      tenantId: user.uid,
      roomId: tenantDoc.data()?.roomId,
      type,
      description,
      status: 'open',
      assignedTo: null,
      createdAt: FieldValue.serverTimestamp(),
      resolvedAt: null,
    });

    const response = jsonResponse({ success: true, complaintId });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
