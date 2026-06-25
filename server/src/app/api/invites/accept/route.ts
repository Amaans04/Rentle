import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody, setAuthCookies } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { generateAccessToken, generateRefreshToken } from '@/lib/jwt';
import { requireString, ValidationError } from '@/lib/validators';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

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
    if (invite.status !== 'pending') throw new ValidationError('Invite is no longer valid');

    const now = Timestamp.now();
    if (invite.expiresAt.toMillis() < now.toMillis()) {
      await inviteDoc.ref.update({ status: 'expired' });
      throw new ValidationError('Invite has expired');
    }

    const userDoc = await db.collection(COLLECTIONS.USERS).doc(user.uid).get();
    const userPhone = userDoc.data()?.phone;
    if (!userPhone || userPhone !== invite.phone) {
      throw new ValidationError('Phone number does not match invite');
    }

    const role = invite.role;
    const pgId = invite.pgId;

    await db.collection(COLLECTIONS.USERS).doc(user.uid).update({
      pgId,
      role,
      onboarded: true,
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (role === 'tenant') {
      await db.collection(COLLECTIONS.TENANTS).doc(user.uid).set({
        uid: user.uid,
        pgId,
        roomId: invite.roomId,
        moveInDate: invite.moveInDate
          ? Timestamp.fromDate(new Date(invite.moveInDate))
          : FieldValue.serverTimestamp(),
        rentAmount: invite.rentAmount || 0,
        depositAmount: invite.depositAmount || 0,
        status: 'active',
        noticeDate: null,
        moveOutDate: null,
        addedBy: invite.invitedBy,
      });

      if (invite.roomId) {
        const roomRef = db.collection(COLLECTIONS.ROOMS).doc(invite.roomId);
        const roomDoc = await roomRef.get();
        if (roomDoc.exists) {
          const occupancy = (roomDoc.data()?.currentOccupancy || 0) + 1;
          const capacity = roomDoc.data()?.sharingCapacity || 1;
          let status = 'partial';
          if (occupancy >= capacity) status = 'full';
          if (occupancy === 0) status = 'vacant';
          await roomRef.update({ currentOccupancy: occupancy, status });
        }
      }
    } else if (role === 'manager') {
      await db.collection(COLLECTIONS.STAFF).doc(user.uid).set({
        uid: user.uid,
        pgId,
        role: 'manager',
        name: userDoc.data()?.name || '',
        phone: userPhone,
        addedBy: invite.invitedBy,
        createdAt: FieldValue.serverTimestamp(),
        active: true,
      });
    }

    await inviteDoc.ref.update({ status: 'accepted' });

    const accessToken = generateAccessToken({ uid: user.uid, role, pgId });
    const { token: refreshToken } = await generateRefreshToken({
      uid: user.uid,
      role,
      pgId,
    });

    const response = jsonResponse({
      success: true,
      role,
      pgId,
      token: accessToken,
      refreshToken,
    });
    setAuthCookies(response, accessToken, refreshToken);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
