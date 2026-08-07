import { ComplaintStatus } from "@prisma/client";
import { HttpError } from "../lib/http-errors.js";

const ALLOWED_TRANSITIONS: Record<ComplaintStatus, ComplaintStatus[]> = {
  [ComplaintStatus.OPEN]: [ComplaintStatus.IN_PROGRESS, ComplaintStatus.ESCALATED, ComplaintStatus.CLOSED],
  [ComplaintStatus.IN_PROGRESS]: [ComplaintStatus.RESOLVED, ComplaintStatus.ESCALATED, ComplaintStatus.OPEN],
  [ComplaintStatus.ESCALATED]: [ComplaintStatus.IN_PROGRESS, ComplaintStatus.RESOLVED],
  [ComplaintStatus.RESOLVED]: [ComplaintStatus.CLOSED, ComplaintStatus.REOPENED],
  [ComplaintStatus.REOPENED]: [ComplaintStatus.IN_PROGRESS, ComplaintStatus.ESCALATED],
  [ComplaintStatus.CLOSED]: [ComplaintStatus.REOPENED],
};

export function assertComplaintTransition(from: ComplaintStatus, to: ComplaintStatus): void {
  if (!ALLOWED_TRANSITIONS[from].includes(to)) {
    throw new HttpError(422, "INVALID_TRANSITION", `Cannot move a complaint from ${from} to ${to}.`);
  }
}
