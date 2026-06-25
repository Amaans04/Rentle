import { NextRequest } from 'next/server';
import { jsonResponse, handleApiError, clearAuthCookies } from '@/lib/api';
import { corsHeaders, handleCors } from '@/lib/cors';
import { verifyRefreshToken, revokeRefreshToken } from '@/lib/jwt';

export async function OPTIONS(request: NextRequest) {
  return handleCors(request) || new Response(null, { status: 204 });
}

export async function POST(request: NextRequest) {
  const cors = handleCors(request);
  if (cors) return cors;

  try {
    const refreshToken = request.cookies.get('refresh_token')?.value;
    if (refreshToken) {
      try {
        const payload = await verifyRefreshToken(refreshToken);
        if (payload.jti) await revokeRefreshToken(payload.jti);
      } catch {
        // Token may already be invalid
      }
    }

    const response = jsonResponse({ success: true });
    clearAuthCookies(response);
    Object.entries(corsHeaders(request)).forEach(([k, v]) => response.headers.set(k, v));
    return response;
  } catch (error) {
    return handleApiError(error);
  }
}
