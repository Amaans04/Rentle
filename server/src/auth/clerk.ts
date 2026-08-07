import { createClerkClient, verifyToken } from "@clerk/backend";
import { env } from "../lib/env.js";

export const clerkClient = createClerkClient({
  secretKey: env.CLERK_SECRET_KEY,
  publishableKey: env.CLERK_PUBLISHABLE_KEY,
});

/**
 * Verifies a bearer token from any client (web cookie session or mobile
 * Authorization header) and returns the Clerk user id, or null if invalid.
 * Never trust a userId/orgId that didn't come from this verification.
 */
export async function verifyClerkToken(token: string): Promise<{ clerkUserId: string } | null> {
  try {
    const payload = await verifyToken(token, { secretKey: env.CLERK_SECRET_KEY });
    if (!payload.sub) return null;
    return { clerkUserId: payload.sub };
  } catch {
    return null;
  }
}
