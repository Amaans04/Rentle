import { NextRequest } from 'next/server';
import { successResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireTenant } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, ValidationError } from '@/lib/validators';
import { getPaymentGateway } from '@/providers/upi-deep-link.gateway';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireTenant(user);
    const body = await parseBody<{ recordId: string }>(request);
    const recordId = requireString(body.recordId, 'recordId');

    const db = getDb();
    const recordDoc = await db.collection(COLLECTIONS.RENT_RECORDS).doc(recordId).get();
    if (!recordDoc.exists) throw new ValidationError('Payment record not found');

    const data = recordDoc.data()!;
    if (data.pgId !== pgId || data.tenantId !== user.uid) {
      throw new ValidationError('Forbidden');
    }
    if (data.status === 'paid') {
      throw new ValidationError('This payment is already completed');
    }

    let deepLink = data.paymentDeepLink as string | null;
    if (!deepLink) {
      const amount = (data.amount as number) + ((data.lateFine as number) || 0);
      const description =
        (data.description as string) ||
        `Payment ${data.month}/${data.year}`;
      const payment = await getPaymentGateway().createPaymentIntent({
        pgId,
        amount,
        description,
        transactionRef: recordId,
        tenantId: user.uid,
      });
      deepLink = payment.deepLink ?? null;
      if (deepLink) {
        await recordDoc.ref.update({
          paymentDeepLink: deepLink,
          paymentProvider: payment.provider,
        });
      }
    }

    if (!deepLink) {
      throw new ValidationError('UPI payment is not available. Contact your PG owner.');
    }

    const response = successResponse({
      recordId,
      deepLink,
      amount: data.amount,
      description: data.description ?? null,
      chargeType: data.chargeType ?? 'rent',
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
