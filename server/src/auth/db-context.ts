import type { Prisma, PrismaClient } from "@prisma/client";
import { prisma } from "../lib/prisma.js";

/**
 * The single choke-point for setting the RLS session variable.
 *
 * `organizationId` MUST already be verified — i.e. derived from a real
 * `OrganizationMember` lookup for the authenticated user, never taken
 * directly from a client-supplied header/body field. This is the direct
 * structural fix for the admin-login.js takeover bug in the prior project:
 * a client can *propose* an org id in the URL, but nothing is trusted until
 * resolveOrg() (see pipeline.ts) has verified membership.
 *
 * RLS here is defense-in-depth, not a replacement for the app-level
 * `WHERE organizationId = ctx.organization.id` filter every query still
 * needs — see the ownership re-derivation note in each route.
 *
 * KNOWN RISK (validate in Phase 0 before relying on this): Supabase's pooled
 * connection (pgbouncer transaction mode) can break SET LOCAL scoping across
 * pooled connections, because SET LOCAL is scoped to the transaction on
 * whichever physical connection the pool handed out — if the pool doesn't
 * guarantee the same connection for the lifetime of the transaction, the
 * session var may not apply where expected. Use `directUrl` (a non-pooled
 * connection) for any operation relying on this until that's proven safe on
 * the pooled URL, or confirm pgbouncer's transaction-mode semantics hold for
 * a single Prisma $transaction call.
 */
export async function withOrgContext<T>(
  organizationId: string,
  fn: (tx: Prisma.TransactionClient) => Promise<T>,
  client: PrismaClient = prisma
): Promise<T> {
  return client.$transaction(
    async (tx) => {
      // set_config(..., true) is LOCAL-scoped (reverts at transaction end) and,
      // unlike `SET LOCAL <var> = <value>`, accepts a bound parameter — no
      // string interpolation into SQL, even though organizationId is already
      // a verified internal id by the time this runs.
      await tx.$executeRaw`SELECT set_config('app.current_org_id', ${organizationId}, true)`;
      return fn(tx);
    },
    // Prisma's default interactive-transaction timeout is 5s — comfortably
    // exceeded by any handler doing more than a few sequential round-trips
    // under real network latency (hit this for real in CI: a 9-step test
    // setup failed with "Transaction not found"). generateInvoicesForProperty
    // (services/invoicing.ts) loops per-tenancy inside one of these — a
    // property with enough active tenants would hit the same ceiling in
    // production, not just under test. 30s is generous for our pilot-scale
    // traffic; revisit if a handler ever legitimately needs longer.
    { timeout: 30000, maxWait: 10000 }
  );
}
