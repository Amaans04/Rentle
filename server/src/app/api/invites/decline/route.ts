import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, ValidationError } from '@/lib/validators';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const body = await parseBody<{ inviteId: string }>(request);
    const inviteId = requireString(body.inviteId, 'inviteId');

    const db = getDb();
    const inviteDoc = await db.collection(COLLECTIONS.INVITES).doc(inviteId).get();

    if (!inviteDoc.exists) throw new ValidationError('Invite not found');

    const invite = inviteDoc.data()!;
    const userDoc = await db.collection(COLLECTIONS.USERS).doc(user.uid).get();
    if (userDoc.data()?.phone !== invite.phone) {
      throw new ValidationError('Phone number does not match invite');
    }

    await inviteDoc.ref.update({ status: 'expired' });

    const response = jsonResponse({ success: true });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
