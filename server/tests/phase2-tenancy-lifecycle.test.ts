import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { OrgMemberRole, BedStatus, TenancyStatus, PropertyType } from "@prisma/client";
import { withOrgContext } from "../src/auth/db-context.js";
import { prisma } from "../src/lib/prisma.js";
import { sweepStaleTestData } from "./sweep-stale-test-data.js";

/**
 * Exercises the Phase 2 exit criteria: full onboard→active→notice→move-out
 * cycle via API calls, bed status staying consistent with tenancy state at
 * every step, and isolation extended to per-tenant scoping (resolveTenantContext).
 *
 * Property/room/bed hierarchy is seeded directly via Prisma (already
 * exhaustively tested via the API in Phase 1's suite) so this file can
 * focus on what's actually new: tenancies, onboarding, and the tenant-self
 * routes. Only Clerk's token verification is mocked, same as Phase 1.
 */
vi.mock("../src/auth/clerk.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/auth/clerk.js")>();
  return {
    ...actual,
    verifyClerkToken: vi.fn(async (token: string) => ({ clerkUserId: token })),
  };
});

const hasLiveDb = process.env.RUN_DB_TESTS === "true";

describe.skipIf(!hasLiveDb)("Phase 2: tenancy lifecycle", () => {
  let buildApp: typeof import("../src/app.js").buildApp;
  let app: import("fastify").FastifyInstance;

  let orgAId: string;
  let orgBId: string;
  let ownerAToken: string;
  let tenantAToken: string;
  let tenantNoTenancyToken: string;
  let propertyId: string;
  let bed1Id: string;
  let bed2Id: string;
  let tenancyId: string;
  let onboardingToken: string;

  function auth(token: string) {
    return { authorization: `Bearer ${token}` };
  }

  beforeAll(async () => {
    ({ buildApp } = await import("../src/app.js"));
    app = buildApp();

    await sweepStaleTestData();

    const suffix = Date.now();
    ownerAToken = `test_owner_p2_${suffix}`;
    tenantAToken = `test_tenant_p2_${suffix}`;
    tenantNoTenancyToken = `test_tenant_none_p2_${suffix}`;

    const [ownerA, , ] = await Promise.all([
      prisma.user.create({ data: { clerkId: ownerAToken, email: `${ownerAToken}@test.local` } }),
      prisma.user.create({ data: { clerkId: tenantAToken, email: `${tenantAToken}@test.local` } }),
      prisma.user.create({ data: { clerkId: tenantNoTenancyToken, email: `${tenantNoTenancyToken}@test.local` } }),
    ]);

    const [orgA, orgB] = await Promise.all([
      prisma.organization.create({ data: { clerkOrgId: `test_org_p2a_${suffix}`, name: "Org P2A", slug: `org-p2a-${suffix}` } }),
      prisma.organization.create({ data: { clerkOrgId: `test_org_p2b_${suffix}`, name: "Org P2B", slug: `org-p2b-${suffix}` } }),
    ]);
    orgAId = orgA.id;
    orgBId = orgB.id;

    await prisma.organizationMember.create({ data: { organizationId: orgAId, userId: ownerA.id, role: OrgMemberRole.OWNER } });

    await withOrgContext(orgAId, async (tx) => {
      const property = await tx.property.create({
        data: {
          organizationId: orgAId,
          name: "P2 Test PG",
          slug: `p2-test-pg-${suffix}`,
          type: PropertyType.PG,
          address: { line1: "x", city: "x", state: "x", pincode: "000000" },
        },
      });
      propertyId = property.id;
      const building = await tx.building.create({ data: { propertyId, organizationId: orgAId, name: "Main" } });
      const floor = await tx.floor.create({ data: { buildingId: building.id, organizationId: orgAId, name: "1", level: 1 } });
      const room = await tx.room.create({
        data: { propertyId, floorId: floor.id, organizationId: orgAId, roomNumber: "101", rentAmount: 9000, mrpAmount: 10000 },
      });
      const bed1 = await tx.bed.create({ data: { roomId: room.id, propertyId, organizationId: orgAId, bedLabel: "A" } });
      const bed2 = await tx.bed.create({ data: { roomId: room.id, propertyId, organizationId: orgAId, bedLabel: "B" } });
      bed1Id = bed1.id;
      bed2Id = bed2.id;
    });
  });

  afterAll(async () => {
    await withOrgContext(orgAId, (tx) => tx.auditLog.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.tenantDocument.deleteMany({ where: { tenancy: { organizationId: orgAId } } }));
    await withOrgContext(orgAId, (tx) => tx.tenancyEvent.deleteMany({ where: { tenancy: { organizationId: orgAId } } }));
    await withOrgContext(orgAId, (tx) => tx.tenancy.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.bed.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.room.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.floor.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.building.deleteMany({ where: { organizationId: orgAId } }));
    await prisma.propertyListing.deleteMany({ where: { organizationId: orgAId } });
    await withOrgContext(orgAId, (tx) => tx.property.deleteMany({ where: { organizationId: orgAId } }));
    await prisma.organizationMember.deleteMany({ where: { organizationId: orgAId } });
    await prisma.organization.deleteMany({ where: { id: { in: [orgAId, orgBId] } } });
    await prisma.user.deleteMany({ where: { clerkId: { in: [ownerAToken, tenantAToken, tenantNoTenancyToken] } } });
    await app.close();
  });

  it("owner invites a tenant to bed1 — bed becomes RESERVED, no Tenancy row yet", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/properties/${propertyId}/tenancies/invite`,
      headers: auth(ownerAToken),
      payload: { bedId: bed1Id, rentAmount: 9000, depositAmount: 18000, expiresInDays: 7 },
    });
    expect(res.statusCode).toBe(201);
    onboardingToken = res.json().data.token;
    expect(onboardingToken).toBeTruthy();

    const bed = await withOrgContext(orgAId, (tx) => tx.bed.findUniqueOrThrow({ where: { id: bed1Id } }));
    expect(bed.status).toBe(BedStatus.RESERVED);

    const tenancyCount = await withOrgContext(orgAId, (tx) => tx.tenancy.count({ where: { organizationId: orgAId } }));
    expect(tenancyCount).toBe(0);
  });

  it("inviting to the same bed again fails — it's no longer VACANT", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/properties/${propertyId}/tenancies/invite`,
      headers: auth(ownerAToken),
      payload: { bedId: bed1Id, rentAmount: 9000, depositAmount: 18000 },
    });
    expect(res.statusCode).toBe(409);
  });

  it("tenant accepts the onboarding token — Tenancy is created as PENDING_ONBOARDING", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/tenant/onboarding/accept`,
      headers: auth(tenantAToken),
      payload: { token: onboardingToken, emergencyContact: { name: "Mom", phone: "9999999999" } },
    });
    expect(res.statusCode).toBe(201);
    const tenancy = res.json().data;
    expect(tenancy.status).toBe(TenancyStatus.PENDING_ONBOARDING);
    tenancyId = tenancy.id;

    const events = await withOrgContext(orgAId, (tx) => tx.tenancyEvent.findMany({ where: { tenancyId } }));
    expect(events.map((e) => e.type)).toContain("onboarding_accepted");
  });

  it("accepting the same token twice fails — already has a non-archived tenancy", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/tenant/onboarding/accept`,
      headers: auth(tenantAToken),
      payload: { token: onboardingToken },
    });
    expect(res.statusCode).toBe(409);
  });

  it("tenant can view their own tenancy via /tenant/me", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/tenant/me`,
      headers: auth(tenantAToken),
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.id).toBe(tenancyId);
  });

  it("a tenant with no tenancy in this org gets 404 from /tenant/me", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/tenant/me`,
      headers: auth(tenantNoTenancyToken),
    });
    expect(res.statusCode).toBe(404);
  });

  it("owner activates the tenancy — bed1 becomes OCCUPIED, moveInDate set", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/tenancies/${tenancyId}/activate`,
      headers: auth(ownerAToken),
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.status).toBe(TenancyStatus.ACTIVE);
    expect(res.json().data.moveInDate).toBeTruthy();

    const bed = await withOrgContext(orgAId, (tx) => tx.bed.findUniqueOrThrow({ where: { id: bed1Id } }));
    expect(bed.status).toBe(BedStatus.OCCUPIED);
  });

  it("activating an already-ACTIVE tenancy is rejected by the status machine", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/tenancies/${tenancyId}/activate`,
      headers: auth(ownerAToken),
    });
    expect(res.statusCode).toBe(422);
  });

  it("owner transfers the tenant from bed1 to bed2 — bed1 VACANT, bed2 OCCUPIED", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/tenancies/${tenancyId}/transfer`,
      headers: auth(ownerAToken),
      payload: { newBedId: bed2Id },
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().data.bedId).toBe(bed2Id);

    const [bed1, bed2] = await withOrgContext(orgAId, (tx) =>
      Promise.all([tx.bed.findUniqueOrThrow({ where: { id: bed1Id } }), tx.bed.findUniqueOrThrow({ where: { id: bed2Id } })])
    );
    expect(bed1.status).toBe(BedStatus.VACANT);
    expect(bed2.status).toBe(BedStatus.OCCUPIED);
  });

  it("tenant uploads a document — signed URL, then confirm writes the row", async () => {
    const uploadRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/tenant/documents`,
      headers: auth(tenantAToken),
      payload: { fileName: "aadhaar.jpg", type: "aadhaar" },
    });
    expect(uploadRes.statusCode).toBe(200);
    const { storageKey } = uploadRes.json().data;
    expect(storageKey).toBeTruthy();

    const confirmRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/tenant/documents/confirm`,
      headers: auth(tenantAToken),
      payload: { storageKey, type: "aadhaar", fileName: "aadhaar.jpg", mimeType: "image/jpeg", sizeBytes: 12345 },
    });
    expect(confirmRes.statusCode).toBe(201);

    const docs = await withOrgContext(orgAId, (tx) => tx.tenantDocument.findMany({ where: { tenancyId } }));
    expect(docs).toHaveLength(1);
    expect(docs[0]?.storageKey).toBe(storageKey);
  });

  it("owner gives notice, then moves the tenant out — bed2 returns to VACANT", async () => {
    const noticeRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/tenancies/${tenancyId}/notice`,
      headers: auth(ownerAToken),
    });
    expect(noticeRes.statusCode).toBe(200);
    expect(noticeRes.json().data.status).toBe(TenancyStatus.NOTICE_GIVEN);

    const bedDuringNotice = await withOrgContext(orgAId, (tx) => tx.bed.findUniqueOrThrow({ where: { id: bed2Id } }));
    expect(bedDuringNotice.status).toBe(BedStatus.OCCUPIED); // still occupied during notice period

    const moveOutRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/tenancies/${tenancyId}/move-out`,
      headers: auth(ownerAToken),
    });
    expect(moveOutRes.statusCode).toBe(200);
    expect(moveOutRes.json().data.status).toBe(TenancyStatus.ARCHIVED);
    expect(moveOutRes.json().data.moveOutDate).toBeTruthy();

    const bedAfterMoveOut = await withOrgContext(orgAId, (tx) => tx.bed.findUniqueOrThrow({ where: { id: bed2Id } }));
    expect(bedAfterMoveOut.status).toBe(BedStatus.VACANT);
  });

  it("moving out an already-ARCHIVED tenancy is rejected", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/tenancies/${tenancyId}/move-out`,
      headers: auth(ownerAToken),
    });
    expect(res.statusCode).toBe(422);
  });

  it("the tenant's own /tenant/me now 404s — ARCHIVED tenancies are excluded from resolveTenantContext", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/tenant/me`,
      headers: auth(tenantAToken),
    });
    expect(res.statusCode).toBe(404);
  });

  it("cross-org isolation: the same tenant has no tenancy in org B", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgBId}/tenant/me`,
      headers: auth(tenantAToken),
    });
    expect(res.statusCode).toBe(404);
  });

  it("the full lifecycle produced a TenancyEvent for every transition", async () => {
    const events = await withOrgContext(orgAId, (tx) =>
      tx.tenancyEvent.findMany({ where: { tenancyId }, orderBy: { createdAt: "asc" } })
    );
    const types = events.map((e) => e.type);
    expect(types).toEqual(["onboarding_accepted", "activated", "transferred", "notice_given", "moved_out"]);
  });
});
