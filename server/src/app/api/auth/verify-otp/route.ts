import { NextRequest } from 'next/server';
import {
  successResponse,
  handleApiError,
  parseBody,
  setAuthCookies,
  getClientIp,
} from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import {
  isValidPhone,
  isValidRole,
  isValidOtp,
  sanitizePhone,
  ValidationError,
} from '@/lib/validators';
import { getAuthService } from '@/services/auth';
import { writeAuditLog } from '@/repositories/firestore/audit.repository';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const body = await parseBody<{ phone: string; otp: string; role: string }>(request);
    const phone = sanitizePhone(body.phone);

    if (!isValidPhone(phone)) throw new ValidationError('Invalid phone number');
    if (!isValidOtp(body.otp)) throw new ValidationError('OTP must be 6 digits');
    if (!isValidRole(body.role)) throw new ValidationError('Invalid role');

    const authData = await getAuthService().verifyOtpAndAuthenticate({
      phone,
      otp: body.otp,
      role: body.role,
    });

    await writeAuditLog({
      userId: authData.uid,
      action: 'LOGIN',
      resource: `user:${authData.uid}`,
      metadata: { method: 'phone_otp', isNewUser: authData.isNewUser },
      ipAddress: getClientIp(request),
      userAgent: request.headers.get('user-agent') || undefined,
    });

    const response = successResponse({
      token: authData.token,
      refreshToken: authData.refreshToken,
      uid: authData.uid,
      isNewUser: authData.isNewUser,
      role: authData.role || body.role,
      pgId: authData.pgId,
      hasInvite: authData.hasInvite,
      inviteId: authData.inviteId,
    });

    setAuthCookies(response, authData.token, authData.refreshToken);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
