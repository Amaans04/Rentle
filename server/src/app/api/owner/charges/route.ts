import { NextRequest } from 'next/server';
import { successResponse, handleApiError, parseBody, getClientIp } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwner } from '@/middleware/auth';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { requireString, requireNumber, ValidationError } from '@/lib/validators';
import { isValidChargeType } from '@/lib/charge-types';
import { getChargeService } from '@/services/payment/charge.service';
import { writeAuditLog } from '@/repositories/firestore/audit.repository';

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

    const status = request.nextUrl.searchParams.get('status');
    const query = db.collection(COLLECTIONS.RENT_RECORDS).where('pgId', '==', pgId);

    const snapshot = await query.limit(200).get();
    type ChargeRecord = {
      id: string;
      chargeType?: string;
      status?: string;
      createdAt?: { toMillis?: () => number };
    };
    let records: ChargeRecord[] = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    })) as ChargeRecord[];

    records = records.filter((r) => {
      const chargeType = r.chargeType;
      return chargeType && chargeType !== 'rent';
    });

    if (status) {
      records = records.filter((r) => r.status === status);
    }

    records.sort((a, b) => {
      const aTime = (a.createdAt as { toMillis?: () => number })?.toMillis?.() ?? 0;
      const bTime = (b.createdAt as { toMillis?: () => number })?.toMillis?.() ?? 0;
      return bTime - aTime;
    });

    const response = successResponse({ charges: records.slice(0, 100) });
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

    const tenantId = requireString(body.tenantId, 'tenantId');
    const chargeType = requireString(body.chargeType, 'chargeType');
    const description = requireString(body.description, 'description');
    const amount = requireNumber(body.amount, 'amount');

    if (!isValidChargeType(chargeType)) {
      throw new ValidationError('Invalid charge type');
    }
    if (chargeType === 'rent') {
      throw new ValidationError('Use rent record generation for monthly rent');
    }

    let dueDate: Date | undefined;
    if (body.dueDate) {
      dueDate = new Date(String(body.dueDate));
      if (Number.isNaN(dueDate.getTime())) {
        throw new ValidationError('Invalid due date');
      }
    }

    const record = await getChargeService().createCharge({
      pgId,
      tenantId,
      chargeType,
      description,
      amount,
      dueDate,
      createdBy: user.uid,
    });

    await writeAuditLog({
      organizationId: pgId,
      userId: user.uid,
      action: 'CREATE',
      resource: `charge:${record.id}`,
      metadata: { tenantId, chargeType, amount, description },
      ipAddress: getClientIp(request),
      userAgent: request.headers.get('user-agent') || undefined,
    });

    const response = successResponse({ charge: record });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
