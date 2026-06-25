import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { verifyAccessToken } from '@/lib/jwt';

const PUBLIC_PATHS = ['/login', '/api/auth/send-otp', '/api/auth/verify-otp', '/api/auth/google-session', '/api/auth/refresh', '/api/auth/logout', '/api/invites/check'];
const OWNER_ONLY_PATHS = ['/rooms', '/staff', '/rent-records', '/settings', '/api/owner'];
const MANAGER_ALLOWED_PATHS = ['/dashboard', '/tenants', '/complaints', '/notices'];

function isPublicPath(pathname: string): boolean {
  return PUBLIC_PATHS.some((p) => pathname === p || pathname.startsWith(p + '/'));
}

function isApiPath(pathname: string): boolean {
  return pathname.startsWith('/api/');
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (isPublicPath(pathname)) {
    return NextResponse.next();
  }

  if (pathname === '/') {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  const token =
    request.cookies.get('access_token')?.value ||
    request.headers.get('authorization')?.replace('Bearer ', '');

  if (!token) {
    if (isApiPath(pathname)) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    return NextResponse.redirect(new URL('/login', request.url));
  }

  try {
    const payload = verifyAccessToken(token);

    if (!isApiPath(pathname) && payload.role === 'manager') {
      const allowed = MANAGER_ALLOWED_PATHS.some(
        (p) => pathname === p || pathname.startsWith(p + '/')
      );
      if (!allowed) {
        return NextResponse.redirect(new URL('/dashboard', request.url));
      }
    }

    if (!isApiPath(pathname) && payload.role === 'tenant') {
      return NextResponse.redirect(new URL('/login', request.url));
    }

    const requestHeaders = new Headers(request.headers);
    requestHeaders.set('x-user-uid', payload.uid);
    requestHeaders.set('x-user-role', payload.role || '');
    requestHeaders.set('x-user-pgid', payload.pgId || '');

    return NextResponse.next({ request: { headers: requestHeaders } });
  } catch {
    if (isApiPath(pathname)) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    const response = NextResponse.redirect(new URL('/login', request.url));
    response.cookies.delete('access_token');
    response.cookies.delete('refresh_token');
    return response;
  }
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
};
