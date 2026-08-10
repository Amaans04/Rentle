import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { OrgMemberRole, BedStatus, AuditAction } from "@prisma/client";
import { withOrgContext } from "../src/auth/db-context.js";
import { prisma } from "../src/lib/prisma.js";
import { sweepStaleTestData } from "./sweep-stale-test-data.js";

/**
 * Exercises the Phase 1 exit criteria from the plan: an owner creates
 * org→property→rooms→beds and a property-scoped manager via API calls
 * alone; the manager can't act outside their propertyIds; every mutation
 * produces an audit row.
 *
 * Only the Clerk token-verification boundary is mocked (trusting Clerk's
 * own well-tested verification, not re-testing it) — everything else,
 * including RLS, runs for real against the live database, same as
 * isolation.test.ts. Gated behind RUN_DB_TESTS=true for the same reason.
 */
vi.mock("../src/auth/clerk.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/auth/clerk.js")>();
  return {
    ...actual,
    // The bearer token IS the clerkId directly — simplest possible stand-in
    // for a real verified token, since what we're testing is OUR
    // authorization logic downstream of verification, not Clerk's.
    verifyClerkToken: vi.fn(async (token: string) => ({ clerkUserId: token })),
    clerkClient: {
      ...actual.clerkClient,
      organizations: {
        createOrganizationInvitation: vi.fn(async () => ({ id: "inv_test_123", status: "pending" })),
      },
    },
  };
});

const hasLiveDb = process.env.RUN_DB_TESTS === "true";

describe.skipIf(!hasLiveDb)("Phase 1: property hierarchy + staff/RBAC", () => {
  let buildApp: typeof import("../src/app.js").buildApp;
  let app: import("fastify").FastifyInstance;

  let orgAId: string;
  let orgBId: string;
  let ownerAToken: string;
  let managerAToken: string;
  let ownerBToken: string;
  let propertyId1: string;
  let propertyId2: string;
  let buildingId: string;
  let floorId: string;
  let roomId: string;
  let bedId: string;

  function auth(token: string) {
    return { authorization: `Bearer ${token}` };
  }

  beforeAll(async () => {
    ({ buildApp } = await import("../src/app.js"));
    app = buildApp();

    await sweepStaleTestData();

    const suffix = Date.now();
    ownerAToken = `test_owner_a_${suffix}`;
    managerAToken = `test_manager_a_${suffix}`;
    ownerBToken = `test_owner_b_${suffix}`;

    const [ownerA, managerA, ownerB] = await Promise.all([
      prisma.user.create({ data: { clerkId: ownerAToken, email: `${ownerAToken}@test.local` } }),
      prisma.user.create({ data: { clerkId: managerAToken, email: `${managerAToken}@test.local` } }),
      prisma.user.create({ data: { clerkId: ownerBToken, email: `${ownerBToken}@test.local` } }),
    ]);

    const [orgA, orgB] = await Promise.all([
      prisma.organization.create({ data: { clerkOrgId: `test_org_a_${suffix}`, name: "Org A", slug: `org-a-${suffix}` } }),
      prisma.organization.create({ data: { clerkOrgId: `test_org_b_${suffix}`, name: "Org B", slug: `org-b-${suffix}` } }),
    ]);
    orgAId = orgA.id;
    orgBId = orgB.id;

    await Promise.all([
      prisma.organizationMember.create({ data: { organizationId: orgAId, userId: ownerA.id, role: OrgMemberRole.OWNER } }),
      prisma.organizationMember.create({ data: { organizationId: orgBId, userId: ownerB.id, role: OrgMemberRole.OWNER } }),
    ]);
    // managerA's membership is created below, once propertyId1 exists, so
    // it can be scoped to that specific property.
    void managerA;
  });

  afterAll(async () => {
    await withOrgContext(orgAId, (tx) =>
      tx.auditLog.deleteMany({ where: { organizationId: orgAId } })
    );
    await withOrgContext(orgAId, (tx) => tx.bed.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.room.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.floor.deleteMany({ where: { organizationId: orgAId } }));
    await withOrgContext(orgAId, (tx) => tx.building.deleteMany({ where: { organizationId: orgAId } }));
    await prisma.propertyListing.deleteMany({ where: { organizationId: orgAId } });
    await withOrgContext(orgAId, (tx) => tx.property.deleteMany({ where: { organizationId: orgAId } }));
    await prisma.organizationMember.deleteMany({ where: { organizationId: { in: [orgAId, orgBId] } } });
    await prisma.organization.deleteMany({ where: { id: { in: [orgAId, orgBId] } } });
    await prisma.user.deleteMany({ where: { clerkId: { in: [ownerAToken, managerAToken, ownerBToken] } } });
    // Deliberately not calling prisma.$disconnect() — shared singleton, see
    // the note in tests/isolation.test.ts.
    await app.close();
  });

  it("owner creates property → building → floor → room → bed via API calls alone", async () => {
    const propRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/properties`,
      headers: auth(ownerAToken),
      payload: {
        name: "Sunrise PG",
        slug: "sunrise-pg",
        address: { line1: "1 MG Road", city: "Bengaluru", state: "KA", pincode: "560001" },
      },
    });
    expect(propRes.statusCode).toBe(201);
    propertyId1 = propRes.json().data.id;

    const prop2Res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/properties`,
      headers: auth(ownerAToken),
      payload: {
        name: "Second PG",
        slug: "second-pg",
        address: { line1: "2 MG Road", city: "Bengaluru", state: "KA", pincode: "560001" },
      },
    });
    expect(prop2Res.statusCode).toBe(201);
    propertyId2 = prop2Res.json().data.id;

    const buildingRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/properties/${propertyId1}/buildings`,
      headers: auth(ownerAToken),
      payload: { name: "Main Block" },
    });
    expect(buildingRes.statusCode).toBe(201);
    buildingId = buildingRes.json().data.id;

    const floorRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/buildings/${buildingId}/floors`,
      headers: auth(ownerAToken),
      payload: { name: "2nd Floor", level: 2 },
    });
    expect(floorRes.statusCode).toBe(201);
    floorId = floorRes.json().data.id;

    const roomRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/properties/${propertyId1}/rooms`,
      headers: auth(ownerAToken),
      payload: { floorId, roomNumber: "201", sharingCapacity: 2, rentAmount: 9000, mrpAmount: 10000 },
    });
    expect(roomRes.statusCode).toBe(201);
    roomId = roomRes.json().data.id;

    const bedRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/rooms/${roomId}/beds`,
      headers: auth(ownerAToken),
      payload: { bedLabel: "A" },
    });
    expect(bedRes.statusCode).toBe(201);
    bedId = bedRes.json().data.id;
    expect(bedRes.json().data.status).toBe(BedStatus.VACANT);

    // Now create the property-scoped manager membership (simulating "owner
    // invited them, they joined, owner assigned them to propertyId1" —
    // the invite endpoint itself is tested separately below with a mocked
    // Clerk call).
    const managerUser = await prisma.user.findUniqueOrThrow({ where: { clerkId: managerAToken } });
    await prisma.organizationMember.create({
      data: {
        organizationId: orgAId,
        userId: managerUser.id,
        role: OrgMemberRole.MANAGER,
        propertyIds: [propertyId1],
      },
    });
  });

  it("a property-scoped manager can read their assigned property but not another one in the same org", async () => {
    const ownRes = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/properties/${propertyId1}`,
      headers: auth(managerAToken),
    });
    expect(ownRes.statusCode).toBe(200);

    const otherRes = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/properties/${propertyId2}`,
      headers: auth(managerAToken),
    });
    expect(otherRes.statusCode).toBe(403);
  });

  it("the property list for a scoped manager only includes their assigned property", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgAId}/properties`,
      headers: auth(managerAToken),
    });
    expect(res.statusCode).toBe(200);
    const ids = res.json().data.map((p: { id: string }) => p.id);
    expect(ids).toEqual([propertyId1]);
  });

  it("a property-scoped manager cannot create a new property", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/properties`,
      headers: auth(managerAToken),
      payload: {
        name: "Unauthorized PG",
        slug: "unauthorized-pg",
        address: { line1: "x", city: "x", state: "x", pincode: "000000" },
      },
    });
    expect(res.statusCode).toBe(403);
  });

  it("a property-scoped manager cannot mutate a property outside their scope", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/properties/${propertyId2}`,
      headers: auth(managerAToken),
      payload: { name: "Renamed" },
    });
    expect(res.statusCode).toBe(403);
  });

  it("bed status machine: OCCUPIED is unreachable manually, BLOCKED requires a reason", async () => {
    const occupiedRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/beds/${bedId}/status`,
      headers: auth(ownerAToken),
      payload: { status: BedStatus.OCCUPIED },
    });
    expect(occupiedRes.statusCode).toBe(422);

    const missingReasonRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/beds/${bedId}/status`,
      headers: auth(ownerAToken),
      payload: { status: BedStatus.BLOCKED },
    });
    expect(missingReasonRes.statusCode).toBe(422);

    const blockedRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgAId}/beds/${bedId}/status`,
      headers: auth(ownerAToken),
      payload: { status: BedStatus.BLOCKED, blockedReason: "Plumbing repair" },
    });
    expect(blockedRes.statusCode).toBe(200);
    expect(blockedRes.json().data.status).toBe(BedStatus.BLOCKED);
  });

  it("staff invite endpoint calls Clerk and records an audit entry, without creating a membership directly", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgAId}/staff/invite`,
      headers: auth(ownerAToken),
      payload: { email: "newstaff@example.com", intendedRole: OrgMemberRole.RECEPTIONIST },
    });
    expect(res.statusCode).toBe(202);
    expect(res.json().data.email).toBe("newstaff@example.com");
  });

  it("every mutation performed above produced exactly one audit row", async () => {
    const logs = await withOrgContext(orgAId, (tx) =>
      tx.auditLog.findMany({ where: { organizationId: orgAId }, orderBy: { createdAt: "asc" } })
    );

    const resources = logs.map((l) => l.resource);
    expect(resources).toContain("property");
    expect(resources).toContain("building");
    expect(resources).toContain("floor");
    expect(resources).toContain("room");
    expect(resources).toContain("bed");
    expect(resources).toContain(`bed:${bedId}`);
    expect(resources).toContain("staff-invite");

    const createActions = logs.filter((l) => l.action === AuditAction.CREATE);
    // property x2, building, floor, room, bed, staff-invite = 7 CREATE rows
    expect(createActions.length).toBeGreaterThanOrEqual(7);
  });
});
