function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

function parseBool(value: string | undefined): boolean | undefined {
  if (value === undefined || value === '') return undefined;
  if (value === 'true' || value === '1') return true;
  if (value === 'false' || value === '0') return false;
  return undefined;
}

export const env = {
  get firebaseProjectId() {
    return requireEnv('FIREBASE_PROJECT_ID');
  },
  get firebaseClientEmail() {
    return requireEnv('FIREBASE_CLIENT_EMAIL');
  },
  get firebasePrivateKey() {
    return requireEnv('FIREBASE_PRIVATE_KEY').replace(/\\n/g, '\n');
  },
  get jwtSecret() {
    return requireEnv('JWT_SECRET');
  },
  get jwtRefreshSecret() {
    return requireEnv('JWT_REFRESH_SECRET');
  },
  get allowedOrigins() {
    const raw = process.env.ALLOWED_ORIGINS || 'http://localhost:3000';
    return raw.split(',').map((o) => o.trim()).filter(Boolean);
  },
  get appUrl() {
    return process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
  },
  get isProduction() {
    return process.env.NODE_ENV === 'production';
  },
  get authMode() {
    return process.env.AUTH_MODE || 'development';
  },
  get otpBypass() {
    const explicit = parseBool(process.env.OTP_BYPASS);
    if (explicit !== undefined) return explicit;
    return env.authMode !== 'production';
  },
  get otpExpiryMinutes() {
    return parseInt(process.env.OTP_EXPIRY_MINUTES || '10', 10);
  },
  get otpMaxAttempts() {
    return parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10);
  },
  get firebaseStorageBucket() {
    return (
      process.env.FIREBASE_STORAGE_BUCKET ||
      `${env.firebaseProjectId}.appspot.com`
    );
  },
  get msg91AuthKey() {
    return process.env.MSG91_AUTH_KEY || '';
  },
  get msg91OtpTemplateId() {
    return process.env.MSG91_OTP_TEMPLATE_ID || '';
  },
};
