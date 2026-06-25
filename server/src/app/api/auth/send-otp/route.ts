import { NextRequest } from 'next/server';
import { successResponse, handleApiError, parseBody } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { isValidPhone, isValidRole, sanitizePhone, ValidationError } from '@/lib/validators';
import { getAuthService } from '@/services/auth';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const body = await parseBody<{ phone: string; role: string; resend?: boolean }>(request);
    const phone = sanitizePhone(body.phone);

    if (!isValidPhone(phone)) {
      throw new ValidationError('Invalid phone number');
    }
    if (!isValidRole(body.role)) {
      throw new ValidationError('Invalid role');
    }

    const result = await getAuthService().sendOtp({
      phone,
      role: body.role,
      resend: body.resend,
    });

    const response = successResponse({
      message: body.resend ? 'OTP resent' : 'OTP sent',
      requestId: result.requestId,
      expiresAt: result.expiresAt.toISOString(),
    });
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
