import { prisma } from "../src/lib/prisma.js";

/**
 * Defensive cleanup for stale rows left behind by a previous test run whose
 * afterAll never got to run (e.g. aborted by a timeout). Scoped to the
 * test_-prefix + age, so it can never touch real data, and deletes in
 * FK-safe order (children before parents) — unlike a single test file's
 * own narrower sweep, this covers every table a DB-backed test might have
 * written to, so it's safe to reuse across test files instead of each one
 * reinventing a partial version.
 */
export async function sweepStaleTestData(olderThanMs = 60 * 60 * 1000): Promise<void> {
  const cutoff = new Date(Date.now() - olderThanMs);
  const staleOrgFilter = { clerkOrgId: { startsWith: "test_org_" }, createdAt: { lt: cutoff } };

  const staleOrgIds = (await prisma.organization.findMany({ where: staleOrgFilter, select: { id: true } })).map(
    (o) => o.id
  );
  if (staleOrgIds.length > 0) {
    await prisma.tenantDocument.deleteMany({ where: { tenancy: { organizationId: { in: staleOrgIds } } } });
    await prisma.tenancyEvent.deleteMany({ where: { tenancy: { organizationId: { in: staleOrgIds } } } });
    await prisma.joinRequest.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.tenancy.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.bed.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.room.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.floor.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.building.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.propertyListing.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.property.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.auditLog.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.organizationMember.deleteMany({ where: { organizationId: { in: staleOrgIds } } });
    await prisma.organization.deleteMany({ where: { id: { in: staleOrgIds } } });
  }

  await prisma.user.deleteMany({ where: { clerkId: { startsWith: "test_" }, createdAt: { lt: cutoff } } });
}
