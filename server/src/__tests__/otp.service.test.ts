import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import {
  OtpService,
  hashOtp,
  isOtpBypassEnabled,
  type OtpRepository,
  type OtpSession,
} from '@/services/auth/otp.service';
import { ValidationError } from '@/lib/errors';

function createMockRepository(): OtpRepository & {
  sessions: Map<string, OtpSession>;
} {
  const sessions = new Map<string, OtpSession>();
  return {
    sessions,
    async saveSession(session) {
      sessions.set(session.phone, session);
    },
    async getSessionByPhone(phone) {
      return sessions.get(phone) ?? null;
    },
    async deleteSession(phone) {
      sessions.delete(phone);
    },
    async deleteExpiredSessions() {
      const now = new Date();
      let count = 0;
      for (const [phone, session] of sessions) {
        if (session.expiresAt < now) {
          sessions.delete(phone);
          count++;
        }
      }
      return count;
    },
    async incrementAttemptCount(phone) {
      const session = sessions.get(phone);
      if (!session) return 0;
      session.attemptCount += 1;
      return session.attemptCount;
    },
  };
}

function buildSession(phone: string, otp: string, role: OtpSession['role'] = 'owner'): OtpSession {
  const now = new Date();
  return {
    requestId: 'req-1',
    phone,
    role,
    otpHash: hashOtp(otp),
    createdAt: now,
    expiresAt: new Date(now.getTime() + 10 * 60 * 1000),
    attemptCount: 0,
    maxAttempts: 5,
    verified: false,
  };
}

describe('isOtpBypassEnabled', () => {
  const original = { ...process.env };

  afterEach(() => {
    process.env = { ...original };
  });

  it('returns true when OTP_BYPASS=true', () => {
    process.env.OTP_BYPASS = 'true';
    process.env.AUTH_MODE = 'production';
    expect(isOtpBypassEnabled()).toBe(true);
  });

  it('returns false when OTP_BYPASS=false', () => {
    process.env.OTP_BYPASS = 'false';
    process.env.AUTH_MODE = 'development';
    expect(isOtpBypassEnabled()).toBe(false);
  });

  it('defaults to bypass when AUTH_MODE is not production', () => {
    delete process.env.OTP_BYPASS;
    process.env.AUTH_MODE = 'development';
    expect(isOtpBypassEnabled()).toBe(true);
  });
});

describe('OtpService', () => {
  let repository: ReturnType<typeof createMockRepository>;
  let service: OtpService;

  beforeEach(() => {
    process.env.JWT_SECRET = 'test-secret';
    repository = createMockRepository();
    service = new OtpService(repository);
  });

  afterEach(() => {
    delete process.env.OTP_BYPASS;
  });

  it('stores session on sendOtp', async () => {
    const result = await service.sendOtp('9876543210', 'owner');
    expect(result.requestId).toBeTruthy();
    expect(repository.sessions.has('9876543210')).toBe(true);
  });

  it('rejects wrong OTP in production mode', async () => {
    process.env.OTP_BYPASS = 'false';
    repository.sessions.set('9876543210', buildSession('9876543210', '123456'));
    await expect(
      service.verifyOtp('9876543210', '000000', 'owner'),
    ).rejects.toThrow(ValidationError);
  });

  it('accepts matching OTP in production mode', async () => {
    process.env.OTP_BYPASS = 'false';
    repository.sessions.set('9876543210', buildSession('9876543210', '123456'));
    const verified = await service.verifyOtp('9876543210', '123456', 'owner');
    expect(verified.phone).toBe('9876543210');
    expect(repository.sessions.has('9876543210')).toBe(false);
  });

  it('accepts any 6-digit OTP when bypass is enabled', async () => {
    process.env.OTP_BYPASS = 'true';
    repository.sessions.set('9876543210', buildSession('9876543210', '123456'));
    const verified = await service.verifyOtp('9876543210', '111111', 'owner');
    expect(verified.phone).toBe('9876543210');
  });

  it('rejects expired OTP', async () => {
    process.env.OTP_BYPASS = 'false';
    const session = buildSession('9876543210', '123456');
    session.expiresAt = new Date(Date.now() - 1000);
    repository.sessions.set('9876543210', session);
    await expect(
      service.verifyOtp('9876543210', '123456', 'owner'),
    ).rejects.toThrow('OTP expired');
  });

  it('increments attempts on failed verification', async () => {
    process.env.OTP_BYPASS = 'false';
    repository.sessions.set('8888888888', buildSession('8888888888', '123456'));
    await expect(service.verifyOtp('8888888888', '000000', 'owner')).rejects.toThrow(
      'Invalid OTP',
    );
    expect(repository.sessions.get('8888888888')?.attemptCount).toBe(1);
  });
});

describe('hashOtp', () => {
  beforeEach(() => {
    process.env.JWT_SECRET = 'test-secret';
  });

  it('produces stable hashes', () => {
    expect(hashOtp('123456')).toBe(hashOtp('123456'));
    expect(hashOtp('123456')).not.toBe(hashOtp('654321'));
  });
});
