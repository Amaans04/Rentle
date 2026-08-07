import type { Prisma } from "@prisma/client";
import { withOrgContext } from "../auth/db-context.js";

type IdempotentResult<T> = { statusCode: number; body: T };

/**
 * Backs the Idempotency-Key header on mutation-heavy endpoints (payment
 * recording, invoice generation) — a plain Postgres table (idempotency_keys),
 * no Redis needed at this scale, per plan §3.
 *
 * Called from INSIDE a route handler, wrapping just the business-logic part
 * — the handler still does the actual `reply.status(...).send(...)` with
 * whatever this returns, same shape as withAudit/withRequestOrgContext.
 *
 * Known limitation, acceptable at pilot scale: this is a check-then-act
 * pattern, not a lock. Two truly concurrent requests with the same key can
 * both miss the cache and both execute `fn`. Fine for a small number of
 * pilot users hitting these endpoints one at a time; would need a proper
 * lock (e.g. an advisory lock or a unique-constraint-first-then-execute
 * ordering) before this matters at real scale.
 */
export async function withIdempotency<T>(
  organizationId: string,
  idempotencyKey: string | undefined,
  fn: () => Promise<IdempotentResult<T>>
): Promise<IdempotentResult<T>> {
  if (!idempotencyKey) {
    return fn();
  }

  const existing = await withOrgContext(organizationId, (tx) =>
    tx.idempotencyKey.findUnique({
      where: { organizationId_key: { organizationId, key: idempotencyKey } },
    })
  );
  if (existing) {
    return { statusCode: existing.responseStatus, body: existing.responseBody as T };
  }

  const result = await fn();

  // Best-effort caching of the response — a failure here (e.g. a losing
  // race on the unique constraint) shouldn't fail a request that already
  // succeeded.
  await withOrgContext(organizationId, (tx) =>
    tx.idempotencyKey.create({
      data: {
        organizationId,
        key: idempotencyKey,
        responseStatus: result.statusCode,
        responseBody: result.body as Prisma.InputJsonValue,
      },
    })
  ).catch(() => {});

  return result;
}

export function getIdempotencyKeyHeader(headers: Record<string, string | string[] | undefined>): string | undefined {
  const value = headers["idempotency-key"];
  return typeof value === "string" ? value : undefined;
}
