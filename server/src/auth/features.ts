import type { SubscriptionTier } from "@prisma/client";

// Mirrors the ROLE_PERMISSIONS pattern in permissions.ts. No Growth/Business
// modules are built yet (Phases 0-4 are Starter-only), but the gating
// mechanism ships now so it doesn't need retrofitting later — see plan §2a.
export type FeatureKey =
  | "core-property-ops" // rooms/beds/tenancy/invoicing/complaints/notices — always on
  | "lead-crm"
  | "booking-website"
  | "accounting-ledger"
  | "visitor-management"
  | "food-management"
  | "staff-attendance"
  | "live-payment-gateway"
  | "api-access"
  | "custom-domain";

export const TIER_FEATURES: Record<SubscriptionTier, Set<FeatureKey>> = {
  STARTER: new Set(["core-property-ops"]),
  GROWTH: new Set(["core-property-ops", "lead-crm", "booking-website"]),
  BUSINESS: new Set([
    "core-property-ops",
    "lead-crm",
    "booking-website",
    "accounting-ledger",
    "visitor-management",
    "food-management",
    "staff-attendance",
    "live-payment-gateway",
    "api-access",
    "custom-domain",
  ]),
};

export function tierHasFeature(tier: SubscriptionTier, feature: FeatureKey): boolean {
  return TIER_FEATURES[tier].has(feature);
}
