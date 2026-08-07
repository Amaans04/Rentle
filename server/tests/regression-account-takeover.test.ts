import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { OrgMemberRole, PropertyType } from "@prisma/client";
import { withOrgContext } from "../src/auth/db-context.js";
import { prisma } from "../src/lib/prisma.js";
import { sweepStaleTestData } from "./sweep-stale-test-data.js";

/**
 * Named regression test for the admin-login.js account-takeover bug in the
 * prior project (PG/pgplatform): any authenticated user could claim
 * ownership of any property by supplying its ID in a request body — no
 * membership check at all. Required by the plan's "server done and safe"
 * gate before Phase 5 (mobile) starts.
 *
 * There's no endpoint in this codebase that lets a client claim
 * org/property ownership by ID at all — membership is established only via
 * the signature-verified Clerk webhook (routes/webhooks/clerk.ts). This
 * test proves the practical consequence of that design: a user with zero
 * relationship to an organization cannot read or write anything in it by
 * simply supplying its ID, on any endpoint that takes one.
 */
vi.mock("../src/auth/clerk.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/auth/clerk.js")>();
  return {
    ...actual,
    verifyClerkToken: vi.fn(async (token: string) => ({ clerkUserId: token })),
  };
});

const hasLiveDb = process.env.RUN_DB_TESTS === "true";

describe.skipIf(!hasLiveDb)("regression: account-takeover by supplying an org/property ID", () => {
  let buildApp: typeof import("../src/app.js").buildApp;
  let app: import("fastify").FastifyInstance;

  let orgAId: string;
  let propertyAId: string;
  let outsiderToken: string;

  function auth(token: string) {
    return { authorization: `Bearer ${token}` };
  }

  beforeAll(async () => {
    ({ buildApp } = await import("../src/app.js"));
    app = buildApp();
    await sweepStaleTestData();

    const suffix = Date.now();
    outsiderToken = `test_outsider_regr_${suffix}`;
    await prisma.user.create({ data: { clerkId: outsiderToken, email: `${outsiderToken}@test.local` } });

    const orgOwnerToken = `test_owner_regr_${suffix}`;
    const owner = await prisma.user.create({ data: { clerkId: orgOwnerToken, email: `${orgOwnerToken}@test.local` } });
    const org = await prisma.organization.create({
      data: { clerkOrgId: `test_org_regr_${suffix}`, name: "Org Regression", slug: `org-regr-${suffix}` },
    });
    orgAId = org.id;
    await prisma.organizationMember.create({ data: { organizationId: orgAId, userId: owner.id, role: OrgMemberRole.OWNER } });

    await withOrgContext(orgAId, async (tx) => {
      const property = await tx.property.create({
        data: {
          organizationId: orgAId,
          name: "Regression Test PG",
          slug: `regr-pg-${suffix}`,
          type: PropertyType.PG,
          address: { line1: "x", city: "x", state: "x", pincode: "000000" },
        },
      });
      propertyAId = property.id;
    });
  });

  afterAll(async () => {
    await withOrgContext(orgAId, (tx) => tx.property.deleteMany({ where: { organizationId: orgAId } }));
    await prisma.organizationMember.deleteMany({ where: { organizationId: orgAId } });
    await prisma.organization.deleteMany({ where: { id: orgAId } });
    await prisma.user.deleteMany({ where: { clerkId: { startsWith: "test_owner_regr_" } } });
    await prisma.user.deleteMany({ where: { clerkId: outsiderToken } });
    await app.close();
  });

  it("an outsider cannot read the organization by supplying its ID", async () => {
    const res = await app.inject({ method: "GET", url: `/organizations/${orgAId}`, headers: auth(outsiderToken) });
    expect(res.statusCode).toBe(404); // not 403 — resolveOrg doesn't confirm the org even exists to a non-member
  });

  it("an outsider cannot rename/update the organization by supplying its ID", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}`,
      headers: auth(outsiderToken),
      payload: { name: "Hijacked Org" },
    });
    expect(res.statusCode).toBe(404);
  });

  it("an outsider cannot read or write the organization's property by supplying its ID", async () => {
    const readRes = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/properties/${propertyAId}`,
      headers: auth(outsiderToken),
    });
    expect(readRes.statusCode).toBe(404);

    const writeRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/properties/${propertyAId}`,
      headers: auth(outsiderToken),
      payload: { name: "Hijacked Property" },
    });
    expect(writeRes.statusCode).toBe(404);
  });

  it("an outsider cannot list the organization's members by supplying its ID", async () => {
    const res = await app.inject({ method: "GET", url: `/organizations/${orgAId}/members`, headers: auth(outsiderToken) });
    expect(res.statusCode).toBe(404);
  });

  it("the property was never actually modified by any of the above attempts", async () => {
    const property = await withOrgContext(orgAId, (tx) => tx.property.findUniqueOrThrow({ where: { id: propertyAId } }));
    expect(property.name).toBe("Regression Test PG");
  });
});
