import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwnerOrManager } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { isValidPhone, sanitizePhone, ValidationError } from '@/lib/validators';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function GET(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    requireOwnerOrManager(user);

    const phone = request.nextUrl.searchParams.get('phone');
    if (!phone) throw new ValidationError('phone query param required');

    const sanitized = sanitizePhone(phone);
    if (!isValidPhone(sanitized)) throw new ValidationError('Invalid phone number');

    const db = getDb();
    const snapshot = await db
      .collection(COLLECTIONS.USERS)
      .where('phone', '==', sanitized)
      .limit(1)
      .get();

    if (snapshot.empty) {
      const response = jsonResponse({ found: false });
      Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
      return response;
    }

    const userDoc = snapshot.docs[0];
    const data = userDoc.data();

    const response = jsonResponse({
      found: true,
      user: {
        uid: userDoc.id,
        name: data.name,
        phone: data.phone,
        photoURL: data.photoURL,
      },
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
