import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { PrismaClient } from "@prisma/client";
import { withOrgContext } from "../src/auth/db-context.js";

/**
 * The standing cross-org isolation suite required by the Phase 0 exit gate:
 * an automated test proving org A can never read org B's rows, including
 * via a raw-query bypass attempt — not just through the normal Prisma
 * client. This is a permanent CI gate, not a one-time check.
 *
 * Requires a real Supabase Postgres with prisma/rls.sql already applied AND
 * DATABASE_URL/DIRECT_URL pointing at the dedicated `app_user` role (see the
 * warning at the top of prisma/rls.sql) — connecting as the default
 * `postgres` superuser makes this suite pass for the wrong reason, since
 * superusers bypass RLS regardless of policy.
 *
 * Skips (not fails) unless explicitly opted into via RUN_DB_TESTS=true, so
 * `npm test` stays green in this repo's early state without ever silently
 * trying to connect to the dummy/localhost DATABASE_URL used by
 * tests/setup.ts for the DB-independent suites — see docs/PROGRESS.md
 * "blocked on you". Set RUN_DB_TESTS=true once real Supabase credentials
 * (connected as the dedicated app_user role, not the postgres superuser)
 * are in the environment.
 */
const hasLiveDb = process.env.RUN_DB_TESTS === "true";

describe.skipIf(!hasLiveDb)("cross-org isolation (RLS)", () => {
  const prisma = new PrismaClient();
  let orgAId: string;
  let orgBId: string;

  beforeAll(async () => {
    const orgA = await prisma.organization.create({
      data: { clerkOrgId: `test_org_a_${Date.now()}`, name: "Org A (test)", slug: `org-a-${Date.now()}` },
    });
    const orgB = await prisma.organization.create({
      data: { clerkOrgId: `test_org_b_${Date.now()}`, name: "Org B (test)", slug: `org-b-${Date.now()}` },
    });
    orgAId = orgA.id;
    orgBId = orgB.id;

    await prisma.property.create({
      data: {
        organizationId: orgBId,
        name: "Org B's Property",
        slug: "org-b-property",
        address: { line1: "test", city: "test", state: "test", pincode: "000000" },
      },
    });
  });

  afterAll(async () => {
    await prisma.property.deleteMany({ where: { organizationId: { in: [orgAId, orgBId] } } });
    await prisma.organization.deleteMany({ where: { id: { in: [orgAId, orgBId] } } });
    await prisma.$disconnect();
  });

  it("org A's session context cannot SELECT org B's properties via the ORM", async () => {
    const rows = await withOrgContext(orgAId, (tx) => tx.property.findMany(), prisma);
    expect(rows).toHaveLength(0);
  });

  it("org A's session context cannot SELECT org B's properties via a raw query (bypass attempt)", async () => {
    const rows = await withOrgContext(
      orgAId,
      (tx) => tx.$queryRaw`SELECT * FROM properties WHERE organization_id = ${orgBId}`,
      prisma
    );
    expect(rows).toHaveLength(0);
  });

  it("org B's own session context CAN see its own property (RLS isn't over-blocking)", async () => {
    const rows = await withOrgContext(orgBId, (tx) => tx.property.findMany(), prisma);
    expect(rows).toHaveLength(1);
  });
});
