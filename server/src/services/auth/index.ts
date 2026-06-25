import { createAuthService } from '@/services/auth/auth.service';
import { getOtpRepository } from '@/repositories/firestore/otp.repository';

let authServiceInstance: ReturnType<typeof createAuthService> | null = null;

export function getAuthService() {
  if (!authServiceInstance) {
    authServiceInstance = createAuthService(getOtpRepository());
  }
  return authServiceInstance;
}
