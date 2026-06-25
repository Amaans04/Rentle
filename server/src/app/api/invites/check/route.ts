import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { isValidPhone, sanitizePhone, ValidationError } from '@/lib/validators';
import { Timestamp } from 'firebase-admin/firestore';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function GET(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const phone = request.nextUrl.searchParams.get('phone');
    if (!phone) throw new ValidationError('phone query param required');

    const sanitized = sanitizePhone(phone);
    if (!isValidPhone(sanitized)) throw new ValidationError('Invalid phone number');

    const db = getDb();
    const now = Timestamp.now();
    const snapshot = await db
      .collection(COLLECTIONS.INVITES)
      .where('phone', '==', sanitized)
      .where('status', '==', 'pending')
      .get();

    const invites = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      if (data.expiresAt.toMillis() > now.toMillis()) {
        const pgDoc = await db.collection(COLLECTIONS.PGS).doc(data.pgId).get();
        const inviterDoc = await db.collection(COLLECTIONS.USERS).doc(data.invitedBy).get();
        let roomNumber = null;
        if (data.roomId) {
          const roomDoc = await db.collection(COLLECTIONS.ROOMS).doc(data.roomId).get();
          roomNumber = roomDoc.data()?.roomNumber || null;
        }
        invites.push({
          inviteId: doc.id,
          ...data,
          pgName: pgDoc.data()?.name || '',
          pgAddress: pgDoc.data()?.address || '',
          invitedByName: inviterDoc.data()?.name || 'Owner',
          roomNumber,
        });
      }
    }

    const response = jsonResponse({ invites });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
