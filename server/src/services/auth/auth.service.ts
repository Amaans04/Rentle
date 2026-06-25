import { FieldValue } from 'firebase-admin/firestore';
import { getDb, COLLECTIONS } from '@/lib/firebase';
import { buildAuthResponse, type AuthResponse } from '@/lib/auth-helpers';
import type { UserRole } from '@/lib/validators';
import { OtpService } from '@/services/auth/otp.service';
import type { OtpRepository } from '@/services/auth/otp.service';
import { checkOtpRateLimit } from '@/middleware/rateLimit';
import { RateLimitError } from '@/lib/errors';

export interface SendOtpInput {
  phone: string;
  role: UserRole;
  resend?: boolean;
}

export interface VerifyOtpInput {
  phone: string;
  otp: string;
  role: UserRole;
}

export class AuthService {
  constructor(
    private readonly otpService: OtpService,
  ) {}

  async sendOtp(input: SendOtpInput) {
    const allowed = await checkOtpRateLimit(input.phone);
    if (!allowed) {
      throw new RateLimitError('Too many OTP requests. Try again in 10 minutes.');
    }

    return this.otpService.sendOtp(input.phone, input.role, {
      resend: input.resend,
    });
  }

  async verifyOtpAndAuthenticate(input: VerifyOtpInput): Promise<AuthResponse> {
    await this.otpService.verifyOtp(input.phone, input.otp, input.role);

    const db = getDb();
    const usersSnapshot = await db
      .collection(COLLECTIONS.USERS)
      .where('phone', '==', input.phone)
      .limit(1)
      .get();

    let uid: string;
    let isNewUser: boolean;

    if (!usersSnapshot.empty) {
      const userDoc = usersSnapshot.docs[0];
      uid = userDoc.id;
      isNewUser = false;

      if (!userDoc.data().role) {
        await userDoc.ref.update({
          role: input.role,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    } else {
      const newUserRef = db.collection(COLLECTIONS.USERS).doc();
      uid = newUserRef.id;
      isNewUser = true;

      await newUserRef.set({
        uid,
        name: '',
        phone: input.phone,
        email: null,
        photoURL: null,
        role: input.role,
        pgId: null,
        authProvider: 'phone',
        onboarded: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        pushToken: null,
      });
    }

    return buildAuthResponse(uid, isNewUser, input.phone);
  }
}

export function createAuthService(repository: OtpRepository): AuthService {
  return new AuthService(new OtpService(repository));
}
