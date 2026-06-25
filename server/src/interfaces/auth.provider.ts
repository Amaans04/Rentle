import type { UserRole } from '@/lib/validators';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthenticatedUser {
  uid: string;
  role: UserRole | null;
  pgId: string | null;
  isNewUser: boolean;
  hasInvite: boolean;
  inviteId: string | null;
}

/**
 * Abstraction over authentication providers (custom JWT today, Clerk later).
 */
export interface AuthProvider {
  sendOtp(phone: string, role: UserRole, options?: { resend?: boolean }): Promise<{
    requestId: string;
    expiresAt: Date;
  }>;

  verifyOtp(phone: string, otp: string, role: UserRole): Promise<AuthenticatedUser & AuthTokens>;
}
