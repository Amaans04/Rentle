import { createHash, randomInt } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { env } from '@/lib/env';
import { ValidationError } from '@/lib/errors';
import { logger } from '@/lib/logger';
import { getSmsProvider } from '@/integrations/sms.adapter';
import type { UserRole } from '@/lib/validators';

export interface OtpSession {
  requestId: string;
  phone: string;
  role: UserRole;
  otpHash: string;
  createdAt: Date;
  expiresAt: Date;
  attemptCount: number;
  maxAttempts: number;
  verified: boolean;
}

export interface OtpRepository {
  saveSession(session: OtpSession): Promise<void>;
  getSessionByPhone(phone: string): Promise<OtpSession | null>;
  deleteSession(phone: string): Promise<void>;
  deleteExpiredSessions(before: Date): Promise<number>;
  incrementAttemptCount(phone: string): Promise<number>;
}

export interface SendOtpResult {
  requestId: string;
  expiresAt: Date;
  /** Only populated in development for console logging — never returned to client. */
  otp?: string;
}

export interface VerifyOtpResult {
  phone: string;
  role: UserRole;
  requestId: string;
}

export function hashOtp(otp: string): string {
  return createHash('sha256')
    .update(`${otp}:${env.jwtSecret}`)
    .digest('hex');
}

export function generateOtpCode(): string {
  return randomInt(100000, 1000000).toString();
}

/**
 * Single source of truth for development OTP bypass.
 * Set OTP_BYPASS=false or AUTH_MODE=production to enforce OTP matching.
 */
export function isOtpBypassEnabled(): boolean {
  return env.otpBypass;
}

export class OtpService {
  constructor(private readonly repository: OtpRepository) {}

  async sendOtp(phone: string, role: UserRole, options?: { resend?: boolean }): Promise<SendOtpResult> {
    await this.repository.deleteExpiredSessions(new Date());

    const requestId = uuidv4();
    const otp = generateOtpCode();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + env.otpExpiryMinutes * 60 * 1000);

    const session: OtpSession = {
      requestId,
      phone,
      role,
      otpHash: hashOtp(otp),
      createdAt: now,
      expiresAt,
      attemptCount: 0,
      maxAttempts: env.otpMaxAttempts,
      verified: false,
    };

    await this.repository.saveSession(session);

    logger.info('auth.otp.sent', {
      phone,
      role,
      requestId,
      expiresAt: expiresAt.toISOString(),
      resend: options?.resend ?? false,
    });

    if (isOtpBypassEnabled()) {
      logger.info('auth.otp.dev_code', {
        phone,
        role,
        requestId,
        otp,
        message: 'Development mode — any 6-digit OTP is accepted at verify',
      });
      console.log(`[OTP DEV] +91${phone} → ${otp} (requestId: ${requestId}, role: ${role})`);
    } else {
      const sms = getSmsProvider();
      await sms.send({
        to: phone,
        body: `Your Rentle verification code is ${otp}. Valid for ${env.otpExpiryMinutes} minutes.`,
        templateId: env.msg91OtpTemplateId || undefined,
        variables: { otp },
      });
      logger.info('auth.otp.dispatched', { phone, requestId });
    }

    return { requestId, expiresAt, otp: isOtpBypassEnabled() ? otp : undefined };
  }

  async verifyOtp(phone: string, otp: string, role: UserRole): Promise<VerifyOtpResult> {
    const session = await this.repository.getSessionByPhone(phone);

    if (!session) {
      throw new ValidationError('OTP expired or not found. Request a new code.');
    }

    if (session.role !== role) {
      throw new ValidationError('Invalid OTP session');
    }

    if (session.verified) {
      throw new ValidationError('OTP already used. Request a new code.');
    }

    if (new Date() > session.expiresAt) {
      await this.repository.deleteSession(phone);
      throw new ValidationError('OTP expired. Request a new code.');
    }

    if (session.attemptCount >= session.maxAttempts) {
      await this.repository.deleteSession(phone);
      throw new ValidationError('Too many failed attempts. Request a new code.');
    }

    const otpValid = this.validateOtpMatch(otp, session.otpHash);

    if (!otpValid) {
      const attempts = await this.repository.incrementAttemptCount(phone);
      logger.warn('auth.otp.verify_failed', {
        phone,
        requestId: session.requestId,
        attemptCount: attempts,
      });
      throw new ValidationError('Invalid OTP');
    }

    await this.repository.deleteSession(phone);

    logger.info('auth.otp.verified', {
      phone,
      role,
      requestId: session.requestId,
      bypass: isOtpBypassEnabled(),
    });

    return { phone, role, requestId: session.requestId };
  }

  /** The only place OTP comparison is bypassed. */
  private validateOtpMatch(otp: string, storedHash: string): boolean {
    if (isOtpBypassEnabled()) {
      return true;
    }
    return hashOtp(otp) === storedHash;
  }
}
