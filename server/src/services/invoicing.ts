import { InvoiceStatus, TenancyStatus, type Prisma, type PrismaClient } from "@prisma/client";
import { withAudit } from "../lib/with-audit.js";

export function computeInvoicePeriod(year: number, month: number): { periodStart: Date; periodEnd: Date } {
  // month is 1-indexed (1 = January) throughout this module, matching how
  // callers naturally think about "generate for March 2026" — Date's own
  // 0-indexed month is only used internally.
  const periodStart = new Date(Date.UTC(year, month - 1, 1));
  const periodEnd = new Date(Date.UTC(year, month, 0, 23, 59, 59, 999)); // day 0 of next month = last day of this one
  return { periodStart, periodEnd };
}

/** Clamps rentDueDay (1-28) to the actual last day of the month — irrelevant in practice since
 *  rentDueDay is capped at 28 in the Property schema/validation, but kept for correctness. */
export function computeDueDate(rentDueDay: number, year: number, month: number): Date {
  const lastDayOfMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const day = Math.min(rentDueDay, lastDayOfMonth);
  return new Date(Date.UTC(year, month - 1, day));
}

export function isPastGracePeriod(dueDate: Date, gracePeriodDays: number, now: Date): boolean {
  const graceEnd = new Date(dueDate);
  graceEnd.setUTCDate(graceEnd.getUTCDate() + gracePeriodDays);
  return now > graceEnd;
}

export function initialInvoiceStatus(dueDate: Date, gracePeriodDays: number, now: Date): InvoiceStatus {
  return isPastGracePeriod(dueDate, gracePeriodDays, now) ? InvoiceStatus.OVERDUE : InvoiceStatus.SENT;
}

/** One invoice per (tenancy, period) — this doubles as the natural dedup key generation checks against. */
export function generateInvoiceNumber(year: number, month: number, tenancyId: string): string {
  const period = `${year}${String(month).padStart(2, "0")}`;
  return `INV-${period}-${tenancyId.slice(-8)}`;
}

/**
 * Generates one invoice per ACTIVE tenancy in a property for the given
 * period, skipping any tenancy that already has one (the invoiceNumber's
 * uniqueness constraint would catch a race anyway, but checking first
 * avoids a noisy failed-insert in the common "already generated" case —
 * this function is called both from the manual trigger and, once daily,
 * from every property in every org via the cron, so re-running it for an
 * already-invoiced period needs to be a safe no-op, not an error).
 */
export async function generateInvoicesForProperty(
  tx: Prisma.TransactionClient | PrismaClient,
  params: {
    organizationId: string;
    propertyId: string;
    year: number;
    month: number;
    actorUserId?: string;
  }
) {
  const property = await tx.property.findFirst({
    where: { id: params.propertyId, organizationId: params.organizationId, deletedAt: null },
  });
  if (!property) return [];

  const { periodStart, periodEnd } = computeInvoicePeriod(params.year, params.month);
  const dueDate = computeDueDate(property.rentDueDay, params.year, params.month);
  const status = initialInvoiceStatus(dueDate, property.gracePeriodDays, new Date());

  const activeTenancies = await tx.tenancy.findMany({
    where: {
      propertyId: params.propertyId,
      organizationId: params.organizationId,
      status: TenancyStatus.ACTIVE,
      deletedAt: null,
    },
  });

  const created = [];
  for (const tenancy of activeTenancies) {
    const invoiceNumber = generateInvoiceNumber(params.year, params.month, tenancy.id);

    const existing = await tx.invoice.findUnique({
      where: { organizationId_invoiceNumber: { organizationId: params.organizationId, invoiceNumber } },
    });
    if (existing) continue;

    const invoice = await withAudit(
      tx as Prisma.TransactionClient,
      {
        organizationId: params.organizationId,
        userId: params.actorUserId,
        action: "CREATE",
        resource: "invoice",
        metadata: { tenancyId: tenancy.id, period: `${params.year}-${params.month}` },
      },
      () =>
        tx.invoice.create({
          data: {
            organizationId: params.organizationId,
            propertyId: params.propertyId,
            tenancyId: tenancy.id,
            invoiceNumber,
            periodStart,
            periodEnd,
            dueDate,
            subtotal: tenancy.rentAmount,
            totalAmount: tenancy.rentAmount,
            status,
            lineItems: {
              create: [{ description: "Monthly rent", category: "rent", quantity: 1, unitPrice: tenancy.rentAmount, amount: tenancy.rentAmount }],
            },
          },
        })
    );
    created.push(invoice);
  }

  return created;
}
