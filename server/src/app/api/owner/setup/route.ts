import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody, setAuthCookies } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireRole } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { generateAccessToken, generateRefreshToken } from '@/lib/jwt';
import {
  requireString,
  requireNumber,
  validateRentDueDate,
  validateGenderType,
  ValidationError,
} from '@/lib/validators';
import { FieldValue } from 'firebase-admin/firestore';
import { v4 as uuidv4 } from 'uuid';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    requireRole(user, 'owner');

    const body = await parseBody<Record<string, unknown>>(request);
    const name = requireString(body.name, 'name');
    const propertyName = requireString(body.propertyName, 'propertyName');
    const address = requireString(body.address, 'address');
    const city = requireString(body.city, 'city');
    const roomCount = requireNumber(body.roomCount, 'roomCount');
    const genderType = requireString(body.genderType, 'genderType');
    const rentDueDate = requireNumber(body.rentDueDate, 'rentDueDate');
    const contactPhone = requireString(body.contactPhone, 'contactPhone');
    const upiId = typeof body.upiId === 'string' ? body.upiId.trim() : '';

    validateRentDueDate(rentDueDate);
    validateGenderType(genderType);

    if (roomCount < 1 || roomCount > 500) {
      throw new ValidationError('Room count must be between 1 and 500');
    }

    const db = getDb();
    const pgId = uuidv4();

    await db.collection(COLLECTIONS.PGS).doc(pgId).set({
      pgId,
      name: propertyName,
      address,
      city,
      ownerId: user.uid,
      roomCount,
      rentDueDate,
      active: true,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      amenities: [],
      contactPhone,
      genderType,
      upiId: upiId || null,
    });

    await db.collection(COLLECTIONS.USERS).doc(user.uid).update({
      name,
      pgId,
      role: 'owner',
      onboarded: true,
      updatedAt: FieldValue.serverTimestamp(),
    });

    const accessToken = generateAccessToken({ uid: user.uid, role: 'owner', pgId });
    const { token: refreshToken } = await generateRefreshToken({
      uid: user.uid,
      role: 'owner',
      pgId,
    });

    const response = jsonResponse({
      success: true,
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
