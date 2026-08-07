import type { FastifyInstance } from "fastify";
import { env } from "../../lib/env.js";
import { prisma } from "../../lib/prisma.js";
import { withOrgContext } from "../../auth/db-context.js";
import { ok, fail } from "../../lib/api-response.js";
import { generateInvoicesForProperty } from "../../services/invoicing.js";

/**
 * Called once daily by .github/workflows/daily-jobs.yml. Generation itself
 * is idempotent per (tenancy, period) — see generateInvoicesForProperty —
 * so running this every day regardless of each property's own rentDueDay is
 * safe: a property whose invoices already exist for the current period is
 * just a no-op pass, not an error. Protected by the same shared secret as
 * /internal/health, for the same machine-to-machine reason.
 */
export async function internalInvoiceRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post("/internal/invoices/generate", async (request, reply) => {
    const provided = request.headers["x-internal-secret"];
    if (provided !== env.INTERNAL_CRON_SECRET) {
      return reply.status(401).send(fail("UNAUTHORIZED", "Authentication required."));
    }

    const now = new Date();
    const year = now.getUTCFullYear();
    const month = now.getUTCMonth() + 1;

    // organizations has no RLS (see the note at the top of prisma/rls.sql) —
    // this is the one place that's the correct, intended use of that: a
    // trusted machine-to-machine job that legitimately needs to iterate
    // every org, not a per-request handler trusting client input.
    const organizations = await prisma.organization.findMany({ where: { deletedAt: null }, select: { id: true } });

    let totalGenerated = 0;
    const perOrg: Array<{ organizationId: string; generated: number }> = [];

    for (const org of organizations) {
      const generated = await withOrgContext(org.id, async (tx) => {
        const properties = await tx.property.findMany({ where: { organizationId: org.id, deletedAt: null } });
        let count = 0;
        for (const property of properties) {
          const invoices = await generateInvoicesForProperty(tx, {
            organizationId: org.id,
            propertyId: property.id,
            year,
            month,
          });
          count += invoices.length;
        }
        return count;
      });

      totalGenerated += generated;
      if (generated > 0) perOrg.push({ organizationId: org.id, generated });
    }

    return reply.status(200).send(ok({ year, month, totalGenerated, perOrg }));
  });
}
