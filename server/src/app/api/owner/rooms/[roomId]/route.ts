import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwner } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, requireNumber, validateRoomType, ValidationError } from '@/lib/validators';
import { FieldValue } from 'firebase-admin/firestore';

function computeRoomStatus(occupancy: number, capacity: number): string {
  if (occupancy <= 0) return 'vacant';
  if (occupancy >= capacity) return 'full';
  return 'partial';
}

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

async function getRoomForOwner(pgId: string, roomId: string) {
  const db = getDb();
  const roomDoc = await db.collection(COLLECTIONS.ROOMS).doc(roomId).get();
  if (!roomDoc.exists || roomDoc.data()?.pgId !== pgId) {
    throw new ValidationError('Room not found');
  }
  return roomDoc;
}

export async function PUT(
  request: NextRequest,
  { params }: { params: { roomId: string } }
) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwner(user);
    const roomDoc = await getRoomForOwner(pgId, params.roomId);
    const current = roomDoc.data()!;

    const body = await parseBody<Record<string, unknown>>(request);
    const updates: Record<string, unknown> = { updatedAt: FieldValue.serverTimestamp() };

    if (body.roomNumber) updates.roomNumber = requireString(body.roomNumber, 'roomNumber');
    if (body.roomType) {
      validateRoomType(body.roomType as string);
      updates.roomType = body.roomType;
    }
    if (body.sharingCapacity != null) {
      updates.sharingCapacity = requireNumber(body.sharingCapacity, 'sharingCapacity');
    }
    if (body.rentAmount != null) updates.rentAmount = requireNumber(body.rentAmount, 'rentAmount');
    if (body.mrpAmount != null) updates.mrpAmount = requireNumber(body.mrpAmount, 'mrpAmount');
    if (body.floor != null) updates.floor = requireNumber(body.floor, 'floor');

    const occupancy = current.currentOccupancy || 0;
    const capacity =
      (updates.sharingCapacity as number | undefined) ?? current.sharingCapacity ?? 1;

    if (capacity < occupancy) {
      throw new ValidationError(
        'Bed capacity cannot be less than current occupancy',
      );
    }

    updates.status = computeRoomStatus(occupancy, capacity);

    const roomRef = getDb().collection(COLLECTIONS.ROOMS).doc(params.roomId);
    await roomRef.update(updates);

    const updatedDoc = await roomRef.get();
    const response = jsonResponse({
      success: true,
      room: { id: updatedDoc.id, ...updatedDoc.data() },
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: { roomId: string } }
) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwner(user);
    const roomDoc = await getRoomForOwner(pgId, params.roomId);
    const db = getDb();

    const occupancy = roomDoc.data()?.currentOccupancy || 0;
    if (occupancy > 0) {
      throw new ValidationError('Cannot delete a room with tenants. Move tenants out first.');
    }

    const activeTenants = await db
      .collection(COLLECTIONS.TENANTS)
      .where('pgId', '==', pgId)
      .where('roomId', '==', params.roomId)
      .where('status', '==', 'active')
      .limit(1)
      .get();

    if (!activeTenants.empty) {
      throw new ValidationError('Cannot delete a room with active tenants');
    }

    const pendingInvites = await db
      .collection(COLLECTIONS.INVITES)
      .where('pgId', '==', pgId)
      .where('roomId', '==', params.roomId)
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (!pendingInvites.empty) {
      throw new ValidationError(
        'Cannot delete a room with pending tenant invites. Cancel or wait for invites to expire.',
      );
    }

    await db.collection(COLLECTIONS.ROOMS).doc(params.roomId).delete();

    const response = jsonResponse({ success: true });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
