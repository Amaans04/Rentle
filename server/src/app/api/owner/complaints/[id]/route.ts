import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwnerOrManager } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { ValidationError } from '@/lib/validators';
import { FieldValue } from 'firebase-admin/firestore';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function PUT(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwnerOrManager(user);
    const db = getDb();

    const complaintDoc = await db.collection(COLLECTIONS.COMPLAINTS).doc(params.id).get();
    if (!complaintDoc.exists || complaintDoc.data()?.pgId !== pgId) {
      throw new ValidationError('Complaint not found');
    }

    const body = await parseBody<{ status?: string; assignedTo?: string }>(request);
    const updates: Record<string, unknown> = {};

    if (body.status) {
      if (!['open', 'in_progress', 'resolved'].includes(body.status)) {
        throw new ValidationError('Invalid status');
      }
      updates.status = body.status;
      if (body.status === 'resolved') {
        updates.resolvedAt = FieldValue.serverTimestamp();
      }
    }
    if (body.assignedTo !== undefined) {
      updates.assignedTo = body.assignedTo;
    }

    await db.collection(COLLECTIONS.COMPLAINTS).doc(params.id).update(updates);

    const response = jsonResponse({ success: true });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
