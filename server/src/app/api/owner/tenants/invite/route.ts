import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwnerOrManager } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import {
  isValidPhone,
  sanitizePhone,
  requireString,
  requireNumber,
  ValidationError,
} from '@/lib/validators';
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
    const pgId = requireOwnerOrManager(user);
    const body = await parseBody<Record<string, unknown>>(request);

    const phone = sanitizePhone(requireString(body.phone, 'phone'));
    const roomId = requireString(body.roomId, 'roomId');
    const moveInDate = requireString(body.moveInDate, 'moveInDate');
    const rentAmount = requireNumber(body.rentAmount, 'rentAmount');
    const depositAmount = requireNumber(body.depositAmount, 'depositAmount');
    const tenantName =
      typeof body.name === 'string' ? body.name.trim() : '';

    if (!isValidPhone(phone)) throw new ValidationError('Invalid phone number');

    const db = getDb();

    const usersSnapshot = await db
      .collection(COLLECTIONS.USERS)
      .where('phone', '==', phone)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      const newUserRef = db.collection(COLLECTIONS.USERS).doc();
      await newUserRef.set({
        uid: newUserRef.id,
        name: tenantName,
        phone,
        email: null,
        photoURL: null,
        role: null,
        pgId: null,
        authProvider: 'phone',
        onboarded: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        pushToken: null,
      });
    } else if (tenantName) {
      const userDoc = usersSnapshot.docs[0];
      if (!userDoc.data().name) {
        await userDoc.ref.update({
          name: tenantName,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    const roomDoc = await db.collection(COLLECTIONS.ROOMS).doc(roomId).get();
    if (!roomDoc.exists || roomDoc.data()?.pgId !== pgId) {
      throw new ValidationError('Room not found');
    }

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
      tenantName: tenantName || null,
      role: 'tenant',
      roomId,
      status: 'pending',
      invitedBy: user.uid,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
      moveInDate,
      rentAmount,
      depositAmount,
    });

    const response = jsonResponse({ success: true, inviteId });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
