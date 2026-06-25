import { NextRequest, NextResponse } from 'next/server';
import { AppError, ValidationError } from './errors';
import { logger } from './logger';

// Re-export for backward compatibility with existing imports.
export { ValidationError } from './errors';

export interface ApiSuccessEnvelope<T extends Record<string, unknown>> {
  success: true;
  data?: T;
  [key: string]: unknown;
}

export interface ApiErrorEnvelope {
  success: false;
  error: string;
  code?: string;
}

/** Backward-compatible success response: spreads payload and adds success: true. */
export function successResponse<T extends Record<string, unknown>>(
  payload: T,
  status = 200,
): NextResponse {
  return NextResponse.json({ success: true, ...payload }, { status });
}

/** @deprecated Prefer successResponse — kept for gradual migration. */
export function jsonResponse(data: unknown, status = 200): NextResponse {
  if (data && typeof data === 'object' && !Array.isArray(data)) {
    return NextResponse.json({ success: true, ...(data as object) }, { status });
  }
  return NextResponse.json({ success: true, data }, { status });
}

export function errorResponse(
  message: string,
  status = 400,
  code?: string,
): NextResponse {
  const body: ApiErrorEnvelope = {
    success: false,
    error: message,
    ...(code ? { code } : {}),
  };
  return NextResponse.json(body, { status });
}

export function handleApiError(error: unknown): NextResponse {
  if (error instanceof AppError) {
    logger.warn('api.error', {
      code: error.code,
      message: error.message,
      statusCode: error.statusCode,
    });
    return errorResponse(error.message, error.statusCode, error.code);
  }

  if (error instanceof Error) {
    if (error.message === 'Unauthorized' || error.message === 'Invalid token') {
      return errorResponse('Unauthorized', 401, 'UNAUTHORIZED');
    }
    if (error.message === 'Forbidden') {
      return errorResponse('Forbidden', 403, 'FORBIDDEN');
    }
    logger.error('api.unhandled_error', { message: error.message });
  } else {
    logger.error('api.unhandled_error', { message: 'Unknown error' });
  }

  return errorResponse('Internal server error', 500, 'INTERNAL_ERROR');
}

export async function parseBody<T>(request: NextRequest): Promise<T> {
  try {
    return (await request.json()) as T;
  } catch {
    throw new ValidationError('Invalid JSON body');
  }
}

export function setAuthCookies(
  response: NextResponse,
  accessToken: string,
  refreshToken: string,
): void {
  const isProd = process.env.NODE_ENV === 'production';
  const cookieOptions = {
    httpOnly: true,
    secure: isProd,
    sameSite: 'lax' as const,
    path: '/',
  };

  response.cookies.set('access_token', accessToken, {
    ...cookieOptions,
    maxAge: 15 * 60,
  });
  response.cookies.set('refresh_token', refreshToken, {
    ...cookieOptions,
    maxAge: 7 * 24 * 60 * 60,
  });
}

export function clearAuthCookies(response: NextResponse): void {
  response.cookies.delete('access_token');
  response.cookies.delete('refresh_token');
}

export function getClientIp(request: NextRequest): string | undefined {
  return (
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    request.headers.get('x-real-ip') ||
    undefined
  );
}
