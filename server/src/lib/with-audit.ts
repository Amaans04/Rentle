import type { AuditAction, Prisma } from "@prisma/client";
import { Prisma as PrismaRuntime } from "@prisma/client";

type AuditContext = {
  organizationId?: string;
  userId?: string;
  action: AuditAction;
  resource: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  userAgent?: string;
};

/**
 * Every mutating module should run its write through this, inside the same
 * $transaction, so the audit row can't be silently skipped by a handler
 * that forgot to call it separately (FR-CORE-04).
 *
 * Usage: withOrgContext(orgId, (tx) => withAudit(tx, {...}, () => tx.room.create(...)))
 */
export async function withAudit<T>(
  tx: Prisma.TransactionClient,
  audit: AuditContext,
  fn: () => Promise<T>
): Promise<T> {
  const result = await fn();
  await tx.auditLog.create({
    data: {
      organizationId: audit.organizationId,
      userId: audit.userId,
      action: audit.action,
      resource: audit.resource,
      metadata: audit.metadata === undefined ? PrismaRuntime.JsonNull : (audit.metadata as Prisma.InputJsonValue),
      ipAddress: audit.ipAddress,
      userAgent: audit.userAgent,
    },
  });
  return result;
}
