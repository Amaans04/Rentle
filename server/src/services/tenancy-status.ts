import { TenancyStatus } from "@prisma/client";
import { HttpError } from "../lib/http-errors.js";

const ALLOWED_TRANSITIONS: Record<TenancyStatus, TenancyStatus[]> = {
  [TenancyStatus.PENDING_ONBOARDING]: [TenancyStatus.ACTIVE, TenancyStatus.ARCHIVED],
  [TenancyStatus.ACTIVE]: [TenancyStatus.NOTICE_GIVEN, TenancyStatus.ARCHIVED],
  [TenancyStatus.NOTICE_GIVEN]: [TenancyStatus.ARCHIVED, TenancyStatus.ACTIVE],
  [TenancyStatus.MOVING_OUT]: [TenancyStatus.ARCHIVED],
  [TenancyStatus.ARCHIVED]: [],
  [TenancyStatus.BLACKLISTED]: [],
};

export function assertTenancyTransition(from: TenancyStatus, to: TenancyStatus): void {
  if (!ALLOWED_TRANSITIONS[from].includes(to)) {
    throw new HttpError(422, "INVALID_TRANSITION", `Cannot move a tenancy from ${from} to ${to}.`);
  }
}
