import { NextRequest } from 'next/server';
import { successResponse, handleApiError, getClientIp } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { authenticateRequest, requireOwner } from '@/middleware/auth';
import { getRentRecordService } from '@/services/rent/rent-record.service';
import { writeAuditLog } from '@/repositories/firestore/audit.repository';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const user = authenticateRequest(request);
    const pgId = requireOwner(user);

    const result = await getRentRecordService().generateForCurrentMonth(pgId);

    await writeAuditLog({
      organizationId: pgId,
      userId: user.uid,
      action: 'CREATE',
      resource: `rent_records:${pgId}:${result.year}-${result.month}`,
      metadata: { created: result.created },
      ipAddress: getClientIp(request),
      userAgent: request.headers.get('user-agent') || undefined,
    });

    const response = successResponse({
      created: result.created,
      month: result.month,
      year: result.year,
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
