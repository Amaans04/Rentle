import { BedStatus } from "@prisma/client";
import { HttpError } from "../lib/http-errors.js";

/**
 * OCCUPIED is deliberately unreachable through this manual state-transition
 * endpoint in every direction. Occupancy is a side-effect of a Tenancy
 * becoming ACTIVE / moving out (Phase 2), not something staff sets by hand —
 * setting it manually here would let a bed claim to be occupied with no
 * Tenancy behind it (or vice versa), which is exactly the kind of
 * inconsistency the explicit state-machine endpoint exists to prevent.
 */
export function assertManualBedTransition(from: BedStatus, to: BedStatus): void {
  if (to === BedStatus.OCCUPIED) {
    throw new HttpError(
      422,
      "INVALID_TRANSITION",
      "A bed can only become OCCUPIED by an active Tenancy, not a manual status update."
    );
  }
  if (from === BedStatus.OCCUPIED) {
    throw new HttpError(
      422,
      "INVALID_TRANSITION",
      "An OCCUPIED bed can only change status via the tenancy move-out/transfer flow."
    );
  }
}

export function requiresReservedUntil(to: BedStatus): boolean {
  return to === BedStatus.RESERVED;
}

export function requiresBlockedReason(to: BedStatus): boolean {
  return to === BedStatus.BLOCKED;
}
