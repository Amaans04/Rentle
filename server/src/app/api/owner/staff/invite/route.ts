import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwner } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { isValidPhone, sanitizePhone, requireString, ValidationError } from '@/lib/validators';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { v4 as uuidv4 } from 'uuid';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwner(user);
    const body = await parseBody<{ phone: string }>(request);
    const phone = sanitizePhone(requireString(body.phone, 'phone'));

    if (!isValidPhone(phone)) throw new ValidationError('Invalid phone number');

    const db = getDb();
    const existingInvites = await db
      .collection(COLLECTIONS.INVITES)
      .where('pgId', '==', pgId)
      .where('phone', '==', phone)
      .where('status', '==', 'pending')
      .get();

    if (!existingInvites.empty) {
      throw new ValidationError('An active invite already exists for this phone');
    }

    const inviteId = uuidv4();
    const expiresAt = Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000);

    await db.collection(COLLECTIONS.INVITES).doc(inviteId).set({
      inviteId,
      pgId,
      phone,
      role: 'manager',
      roomId: null,
      status: 'pending',
      invitedBy: user.uid,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
    });

    const response = jsonResponse({ success: true, inviteId });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
