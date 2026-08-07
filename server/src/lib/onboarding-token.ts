import crypto from "node:crypto";
import { env } from "./env.js";

/**
 * Signed, stateless tenant-onboarding tokens — no dedicated "invite" table
 * needed. The Tenancy model requires a real userId (a tenant must already
 * be a Clerk-authenticated User before a Tenancy row can exist), so an
 * invite can't be persisted as a Tenancy the way a staff invite persists
 * nothing extra either (see routes/staff.ts) — this carries the invite's
 * details in the token itself, verified by signature + expiry instead of a
 * database lookup.
 *
 * Signing key is derived from CLERK_SECRET_KEY rather than a new env var —
 * deliberately avoids asking for one more manual credential when an
 * existing secret already gives us a proper HMAC key.
 */
const SIGNING_KEY = crypto.createHash("sha256").update(`${env.CLERK_SECRET_KEY}:tenancy-invite`).digest();

export type OnboardingTokenPayload = {
  organizationId: string;
  propertyId: string;
  bedId: string;
  rentAmount: number;
  depositAmount: number;
  exp: number; // unix seconds
};

export function signOnboardingToken(payload: OnboardingTokenPayload): string {
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = crypto.createHmac("sha256", SIGNING_KEY).update(body).digest("base64url");
  return `${body}.${signature}`;
}

export function verifyOnboardingToken(token: string): OnboardingTokenPayload | null {
  const [body, signature] = token.split(".");
  if (!body || !signature) return null;

  const expectedSignature = crypto.createHmac("sha256", SIGNING_KEY).update(body).digest("base64url");
  const sigBuf = Buffer.from(signature);
  const expectedBuf = Buffer.from(expectedSignature);
  if (sigBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(sigBuf, expectedBuf)) {
    return null;
  }

  let payload: OnboardingTokenPayload;
  try {
    payload = JSON.parse(Buffer.from(body, "base64url").toString("utf-8"));
  } catch {
    return null;
  }

  if (typeof payload.exp !== "number" || payload.exp < Math.floor(Date.now() / 1000)) {
    return null;
  }

  return payload;
}
