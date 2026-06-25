import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwnerOrManager } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, ValidationError } from '@/lib/validators';
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
    const pgId = requireOwnerOrManager(user);
    const db = getDb();

    const snapshot = await db
      .collection(COLLECTIONS.NOTICES)
      .where('pgId', '==', pgId)
      .limit(100)
      .get();

    const notices = snapshot.docs
      .map((doc) => ({ id: doc.id, ...doc.data() } as Record<string, unknown>))
      .sort((a, b) => {
        const aTime =
          (a.createdAt as { toMillis?: () => number })?.toMillis?.() ?? 0;
        const bTime =
          (b.createdAt as { toMillis?: () => number })?.toMillis?.() ?? 0;
        return bTime - aTime;
      });
    const response = jsonResponse({ notices });
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
    const pgId = requireOwnerOrManager(user);
    const body = await parseBody<Record<string, unknown>>(request);

    const title = requireString(body.title, 'title');
    const noticeBody = requireString(body.body, 'body');
    const targetRole = (body.targetRole as string) || 'all';

    if (!['all', 'tenant', 'manager'].includes(targetRole)) {
      throw new ValidationError('Invalid target role');
    }

    const noticeId = uuidv4();
    await getDb().collection(COLLECTIONS.NOTICES).doc(noticeId).set({
      noticeId,
      pgId,
      title,
      body: noticeBody,
      createdBy: user.uid,
      createdAt: FieldValue.serverTimestamp(),
      targetRole,
    });

    const response = jsonResponse({ success: true, noticeId });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
