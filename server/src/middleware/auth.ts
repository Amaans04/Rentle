import { NextRequest } from 'next/server';
import {
  verifyAccessToken,
  extractBearerToken,
  TokenPayload,
  UserRole,
} from '@/lib/jwt';

export interface AuthUser extends TokenPayload {
  role: UserRole;
}

export function getTokenFromRequest(request: NextRequest): string | null {
  const bearer = extractBearerToken(request.headers.get('authorization'));
  if (bearer) return bearer;

  const cookieToken = request.cookies.get('access_token')?.value;
  return cookieToken || null;
}

export function authenticateRequest(request: NextRequest): AuthUser {
  const token = getTokenFromRequest(request);
  if (!token) {
    throw new Error('Unauthorized');
  }

  try {
    const payload = verifyAccessToken(token);
    return payload as AuthUser;
  } catch {
    throw new Error('Unauthorized');
  }
}

export function requireRole(user: AuthUser, ...roles: NonNullable<UserRole>[]): void {
  if (!user.role || !roles.includes(user.role)) {
    throw new Error('Forbidden');
  }
}

export function requirePgId(user: AuthUser): string {
  if (!user.pgId) {
    throw new Error('Forbidden');
  }
  return user.pgId;
}

export function requireOwner(user: AuthUser): string {
  requireRole(user, 'owner');
  return requirePgId(user);
}

export function requireOwnerOrManager(user: AuthUser): string {
  requireRole(user, 'owner', 'manager');
  return requirePgId(user);
}

export function requireTenant(user: AuthUser): string {
  requireRole(user, 'tenant');
  return requirePgId(user);
}
