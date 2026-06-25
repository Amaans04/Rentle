import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwner } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import {
  requireString,
  requireNumber,
  validateRoomType,
} from '@/lib/validators';
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
    const pgId = requireOwner(user);
    const db = getDb();

    const snapshot = await db
      .collection(COLLECTIONS.ROOMS)
      .where('pgId', '==', pgId)
      .get();

    const rooms = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    const response = jsonResponse({ rooms });
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
    const pgId = requireOwner(user);
    const body = await parseBody<Record<string, unknown>>(request);

    const roomNumber = requireString(body.roomNumber, 'roomNumber');
    const roomType = requireString(body.roomType, 'roomType');
    const sharingCapacity = requireNumber(body.sharingCapacity, 'sharingCapacity');
    const rentAmount = requireNumber(body.rentAmount, 'rentAmount');
    const mrpAmount = requireNumber(body.mrpAmount, 'mrpAmount');
    const floor = body.floor != null ? requireNumber(body.floor, 'floor') : null;

    validateRoomType(roomType);

    const db = getDb();
    const roomId = uuidv4();

    await db.collection(COLLECTIONS.ROOMS).doc(roomId).set({
      roomId,
      pgId,
      roomNumber,
      floor,
      roomType,
      sharingCapacity,
      currentOccupancy: 0,
      rentAmount,
      mrpAmount,
      status: 'vacant',
      amenities: [],
      photos: [],
      createdAt: FieldValue.serverTimestamp(),
    });

    const roomDoc = await db.collection(COLLECTIONS.ROOMS).doc(roomId).get();
    const response = jsonResponse({
      success: true,
      roomId,
      room: { id: roomDoc.id, ...roomDoc.data() },
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
