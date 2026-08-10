import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { OrgMemberRole, BedStatus, TenancyStatus, JoinRequestStatus, PropertyType } from "@prisma/client";
import { withOrgContext } from "../src/auth/db-context.js";
import { prisma } from "../src/lib/prisma.js";
import { sweepStaleTestData } from "./sweep-stale-test-data.js";

/**
 * Covers the tenant-discovery scope amendment (2026-08-10): public
 * search-by-name (PropertyListing, deliberately non-RLS) and the
 * JoinRequest flow that bridges "found via search" into the existing,
 * already-tested Tenancy machinery. Property/room/bed hierarchy seeded
 * directly via Prisma, same convention as Phase 1/2. Only Clerk's token
 * verification is mocked.
 */
vi.mock("../src/auth/clerk.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/auth/clerk.js")>();
  return {
    ...actual,
    verifyClerkToken: vi.fn(async (token: string) => ({ clerkUserId: token })),
  };
});

const hasLiveDb = process.env.RUN_DB_TESTS === "true";

describe.skipIf(!hasLiveDb)("Tenant discovery: search + join requests", () => {
  let buildApp: typeof import("../src/app.js").buildApp;
  let app: import("fastify").FastifyInstance;

  let orgAId: string;
  let orgBId: string;
  let ownerAToken: string;
  let ownerBToken: string;
  let tenantToken: string;
  let outsiderToken: string;
  let propertyAId: string;
  let bedAId: string;
  const suffix = Date.now();
  const listingName = `Sunrise PG Koramangala ${suffix}`;

  function auth(token: string) {
    return { authorization: `Bearer ${token}` };
  }

  beforeAll(async () => {
    ({ buildApp } = await import("../src/app.js"));
    app = buildApp();

    await sweepStaleTestData();

    ownerAToken = `test_owner_td_a_${suffix}`;
    ownerBToken = `test_owner_td_b_${suffix}`;
    tenantToken = `test_tenant_td_${suffix}`;
    outsiderToken = `test_outsider_td_${suffix}`;

    const [ownerA, ownerB] = await Promise.all([
      prisma.user.create({ data: { clerkId: ownerAToken, email: `${ownerAToken}@test.local` } }),
      prisma.user.create({ data: { clerkId: ownerBToken, email: `${ownerBToken}@test.local` } }),
      prisma.user.create({ data: { clerkId: tenantToken, email: `${tenantToken}@test.local` } }),
      prisma.user.create({ data: { clerkId: outsiderToken, email: `${outsiderToken}@test.local` } }),
    ]);

    const [orgA, orgB] = await Promise.all([
      prisma.organization.create({ data: { clerkOrgId: `test_org_tda_${suffix}`, name: "Org TDA", slug: `org-tda-${suffix}` } }),
      prisma.organization.create({ data: { clerkOrgId: `test_org_tdb_${suffix}`, name: "Org TDB", slug: `org-tdb-${suffix}` } }),
    ]);
    orgAId = orgA.id;
    orgBId = orgB.id;

    await Promise.all([
      prisma.organizationMember.create({ data: { organizationId: orgAId, userId: ownerA.id, role: OrgMemberRole.OWNER } }),
      prisma.organizationMember.create({ data: { organizationId: orgBId, userId: ownerB.id, role: OrgMemberRole.OWNER } }),
    ]);

    await withOrgContext(orgAId, async (tx) => {
      const property = await tx.property.create({
        data: {
          organizationId: orgAId,
          name: listingName,
          slug: `td-test-pg-${suffix}`,
          type: PropertyType.PG,
          address: { line1: "x", city: "Bengaluru", state: "Karnataka", pincode: "560034" },
        },
      });
      propertyAId = property.id;
      const building = await tx.building.create({ data: { propertyId: propertyAId, organizationId: orgAId, name: "Main" } });
      const floor = await tx.floor.create({ data: { buildingId: building.id, organizationId: orgAId, name: "1", level: 1 } });
      const room = await tx.room.create({
        data: { propertyId: propertyAId, floorId: floor.id, organizationId: orgAId, roomNumber: "101", rentAmount: 9000, mrpAmount: 10000 },
      });
      const bed = await tx.bed.create({ data: { roomId: room.id, propertyId: propertyAId, organizationId: orgAId, bedLabel: "A" } });
      bedAId = bed.id;
      await tx.propertyListing.create({
        data: { organizationId: orgAId, propertyId: propertyAId, name: property.name, city: "Bengaluru", state: "Karnataka" },
      });
    });
  });

  afterAll(async () => {
    await withOrgContext(orgAId, (tx) => tx.tenancyEvent.deleteMany({ where: { tenancy: { organizationId: orgAId } } }));
    await withOrgContext(orgAId, (tx) => tx.joinRequest.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.tenancy.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.bed.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.room.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.floor.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.building.deleteMany({ where: { organizationId: orgAId } }));
    await prisma.propertyListing.deleteMany({ where: { organizationId: orgAId } });
    await withOrgContext(orgAId, (tx) => tx.auditLog.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.property.deleteMany({ where: { organizationId: orgAId } }));
    await prisma.organizationMember.deleteMany({ where: { organizationId: { in: [orgAId, orgBId] } } });
    await prisma.organization.deleteMany({ where: { id: { in: [orgAId, orgBId] } } });
    await prisma.user.deleteMany({ where: { clerkId: { in: [ownerAToken, ownerBToken, tenantToken, outsiderToken] } } });
    await app.close();
  });

  let requestId: string;

  it("search finds the listing by name, across orgs, with no membership required", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/property-listings/search?q=${encodeURIComponent("Sunrise PG Koramangala")}`,
      headers: auth(tenantToken),
    });
    expect(res.statusCode).toBe(200);
    const results = res.json().data;
    expect(results.some((r: { propertyId: string }) => r.propertyId === propertyAId)).toBe(true);
  });

  it("search finds the listing by city too", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/property-listings/search?q=Bengaluru`,
      headers: auth(tenantToken),
    });
    expect(res.statusCode).toBe(200);
    const results = res.json().data;
    expect(results.some((r: { propertyId: string }) => r.propertyId === propertyAId)).toBe(true);
  });

  it("a stranger to org A cannot list its join requests (not a member)", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/join-requests`,
      headers: auth(outsiderToken),
    });
    expect(res.statusCode).toBe(404);
  });

  it("tenant submits a join request for the property found via search", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/join-requests`,
      headers: auth(tenantToken),
      payload: { propertyId: propertyAId, message: "Looking for a single, move-in ASAP" },
    });
    expect(res.statusCode).toBe(201);
    const created = res.json().data;
    expect(created.status).toBe(JoinRequestStatus.PENDING);
    requestId = created.id;
  });

  it("a second request from the same tenant to the same org is rejected as a duplicate", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/join-requests`,
      headers: auth(tenantToken),
      payload: { propertyId: propertyAId },
    });
    expect(res.statusCode).toBe(409);
  });

  it("tenant can see their own pending request via /join-requests/mine", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/join-requests/mine`,
      headers: auth(tenantToken),
    });
    expect(res.statusCode).toBe(200);
    const mine = res.json().data;
    expect(mine).toHaveLength(1);
    expect(mine[0].id).toBe(requestId);
  });

  it("owner B (different org) sees nothing for org A's request", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgBId}/join-requests`,
      headers: auth(ownerBToken),
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data).toHaveLength(0);
  });

  it("owner A sees the pending request", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/join-requests?status=PENDING`,
      headers: auth(ownerAToken),
    });
    expect(res.statusCode).toBe(200);
    const list = res.json().data;
    expect(list).toHaveLength(1);
    expect(list[0].id).toBe(requestId);
    expect(list[0].user.id).toBeTruthy();
  });

  it("owner A approves — creates a Tenancy in PENDING_ONBOARDING and reserves the bed", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/join-requests/${requestId}/approve`,
      headers: auth(ownerAToken),
      payload: { bedId: bedAId, rentAmount: 9000, depositAmount: 18000 },
    });
    expect(res.statusCode).toBe(200);
    const { joinRequest, tenancy } = res.json().data;
    expect(joinRequest.status).toBe(JoinRequestStatus.APPROVED);
    expect(joinRequest.tenancyId).toBe(tenancy.id);
    expect(tenancy.status).toBe(TenancyStatus.PENDING_ONBOARDING);

    const bed = await withOrgContext(orgAId, (tx) => tx.bed.findUniqueOrThrow({ where: { id: bedAId } }));
    expect(bed.status).toBe(BedStatus.RESERVED);

    const events = await withOrgContext(orgAId, (tx) => tx.tenancyEvent.findMany({ where: { tenancyId: tenancy.id } }));
    expect(events.map((e) => e.type)).toContain("join_request_approved");
  });

  it("the tenant can now see the tenancy via /tenant/me — no separate accept step needed", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/tenant/me`,
      headers: auth(tenantToken),
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.status).toBe(TenancyStatus.PENDING_ONBOARDING);
  });

  it("approving the same request again fails — it's no longer PENDING", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/join-requests/${requestId}/approve`,
      headers: auth(ownerAToken),
      payload: { bedId: bedAId, rentAmount: 9000 },
    });
    expect(res.statusCode).toBe(409);
  });

  it("a fresh pending request can be rejected", async () => {
    const createRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/join-requests`,
      headers: auth(outsiderToken),
      payload: { propertyId: propertyAId },
    });
    expect(createRes.statusCode).toBe(201);
    const otherRequestId = createRes.json().data.id;

    const rejectRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/join-requests/${otherRequestId}/reject`,
      headers: auth(ownerAToken),
      payload: { note: "No vacancy in the requested category" },
    });
    expect(rejectRes.statusCode).toBe(200);
    expect(rejectRes.json().data.status).toBe(JoinRequestStatus.REJECTED);
  });
});
