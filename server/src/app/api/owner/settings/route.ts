import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwner } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, validateRentDueDate, validateGenderType } from '@/lib/validators';
import { FieldValue } from 'firebase-admin/firestore';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function PUT(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwner(user);
    const body = await parseBody<Record<string, unknown>>(request);

    const updates: Record<string, unknown> = {
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (body.name) updates.name = requireString(body.name, 'name');
    if (body.address) updates.address = requireString(body.address, 'address');
    if (body.city) updates.city = requireString(body.city, 'city');
    if (body.contactPhone) updates.contactPhone = requireString(body.contactPhone, 'contactPhone');
    if (body.upiId !== undefined) updates.upiId = typeof body.upiId === 'string' ? body.upiId.trim() : null;
    if (body.rentDueDate != null) {
      const day = typeof body.rentDueDate === 'number' ? body.rentDueDate : parseInt(String(body.rentDueDate), 10);
      validateRentDueDate(day);
      updates.rentDueDate = day;
    }
    if (body.genderType) {
      validateGenderType(body.genderType as string);
      updates.genderType = body.genderType;
    }

    await getDb().collection(COLLECTIONS.PGS).doc(pgId).update(updates);

    const response = jsonResponse({ success: true });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
