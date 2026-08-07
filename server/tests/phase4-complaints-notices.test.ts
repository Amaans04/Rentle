import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { OrgMemberRole, TenancyStatus, ComplaintStatus, PropertyType } from "@prisma/client";
import { withOrgContext } from "../src/auth/db-context.js";
import { prisma } from "../src/lib/prisma.js";
import { sweepStaleTestData } from "./sweep-stale-test-data.js";

/**
 * Exercises the Phase 4 exit criteria: a tenant files a complaint, staff
 * resolves it with an audit trail; a floor-targeted notice is visible only
 * to tenants on that floor.
 */
vi.mock("../src/auth/clerk.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/auth/clerk.js")>();
  return {
    ...actual,
    verifyClerkToken: vi.fn(async (token: string) => ({ clerkUserId: token })),
  };
});

const hasLiveDb = process.env.RUN_DB_TESTS === "true";

describe.skipIf(!hasLiveDb)("Phase 4: complaints + notices", () => {
  let buildApp: typeof import("../src/app.js").buildApp;
  let app: import("fastify").FastifyInstance;

  let orgId: string;
  let ownerToken: string;
  let tenant1Token: string;
  let tenant2Token: string;
  let propertyId: string;
  let floor1Id: string;
  let floor2Id: string;
  let room2Id: string;
  let complaintId: string;

  function auth(token: string) {
    return { authorization: `Bearer ${token}` };
  }

  beforeAll(async () => {
    ({ buildApp } = await import("../src/app.js"));
    app = buildApp();
    await sweepStaleTestData();

    const suffix = Date.now();
    ownerToken = `test_owner_p4_${suffix}`;
    tenant1Token = `test_tenant1_p4_${suffix}`;
    tenant2Token = `test_tenant2_p4_${suffix}`;

    const owner = await prisma.user.create({ data: { clerkId: ownerToken, email: `${ownerToken}@test.local` } });
    const tenant1User = await prisma.user.create({ data: { clerkId: tenant1Token, email: `${tenant1Token}@test.local` } });
    const tenant2User = await prisma.user.create({ data: { clerkId: tenant2Token, email: `${tenant2Token}@test.local` } });

    const org = await prisma.organization.create({
      data: { clerkOrgId: `test_org_p4_${suffix}`, name: "Org P4", slug: `org-p4-${suffix}` },
    });
    orgId = org.id;
    await prisma.organizationMember.create({ data: { organizationId: orgId, userId: owner.id, role: OrgMemberRole.OWNER } });

    await withOrgContext(orgId, async (tx) => {
      const property = await tx.property.create({
        data: {
          organizationId: orgId,
          name: "P4 Test PG",
          slug: `p4-test-pg-${suffix}`,
          type: PropertyType.PG,
          address: { line1: "x", city: "x", state: "x", pincode: "000000" },
        },
      });
      propertyId = property.id;
      const building = await tx.building.create({ data: { propertyId, organizationId: orgId, name: "Main" } });

      const floor1 = await tx.floor.create({ data: { buildingId: building.id, organizationId: orgId, name: "1", level: 1 } });
      const floor2 = await tx.floor.create({ data: { buildingId: building.id, organizationId: orgId, name: "2", level: 2 } });
      floor1Id = floor1.id;
      floor2Id = floor2.id;

      const room1 = await tx.room.create({
        data: { propertyId, floorId: floor1Id, organizationId: orgId, roomNumber: "101", rentAmount: 9000, mrpAmount: 10000 },
      });
      const room2 = await tx.room.create({
        data: { propertyId, floorId: floor2Id, organizationId: orgId, roomNumber: "201", rentAmount: 9000, mrpAmount: 10000 },
      });
      room2Id = room2.id;

      const bed1 = await tx.bed.create({ data: { roomId: room1.id, propertyId, organizationId: orgId, bedLabel: "A", status: "OCCUPIED" } });
      const bed2 = await tx.bed.create({ data: { roomId: room2.id, propertyId, organizationId: orgId, bedLabel: "A", status: "OCCUPIED" } });

      await tx.tenancy.create({
        data: {
          organizationId: orgId,
          propertyId,
          bedId: bed1.id,
          userId: tenant1User.id,
          status: TenancyStatus.ACTIVE,
          rentAmount: 9000,
          moveInDate: new Date(),
        },
      });
      await tx.tenancy.create({
        data: {
          organizationId: orgId,
          propertyId,
          bedId: bed2.id,
          userId: tenant2User.id,
          status: TenancyStatus.ACTIVE,
          rentAmount: 9000,
          moveInDate: new Date(),
        },
      });
    });
  });

  afterAll(async () => {
    await withOrgContext(orgId, (tx) => tx.auditLog.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.complaintComment.deleteMany({ where: { complaint: { organizationId: orgId } } }));
    await withOrgContext(orgId, (tx) => tx.complaint.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.notice.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.tenancy.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.bed.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.room.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.floor.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.building.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.property.deleteMany({ where: { organizationId: orgId } }));
    await prisma.organizationMember.deleteMany({ where: { organizationId: orgId } });
    await prisma.organization.deleteMany({ where: { id: orgId } });
    await prisma.user.deleteMany({ where: { clerkId: { in: [ownerToken, tenant1Token, tenant2Token] } } });
    await app.close();
  });

  it("tenant1 files a complaint", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/tenant/complaints`,
      headers: auth(tenant1Token),
      payload: { title: "Leaking tap", description: "Bathroom tap won't stop dripping", category: "plumbing" },
    });
    expect(res.statusCode).toBe(201);
    complaintId = res.json().data.id;
    expect(res.json().data.status).toBe(ComplaintStatus.OPEN);
  });

  it("tenant2 cannot view tenant1's complaint — ownership re-derivation, not just org scoping", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgId}/tenant/complaints/${complaintId}`,
      headers: auth(tenant2Token),
    });
    expect(res.statusCode).toBe(404);
  });

  it("tenant1 can view their own complaint", async () => {
    const res = await app.inject({
      method: "GET",
      url: `/organizations/${orgId}/tenant/complaints/${complaintId}`,
      headers: auth(tenant1Token),
    });
    expect(res.statusCode).toBe(200);
  });

  it("owner sees the complaint in the property list and assigns it to themself", async () => {
    const listRes = await app.inject({
      method: "GET",
      url: `/organizations/${orgId}/properties/${propertyId}/complaints`,
      headers: auth(ownerToken),
    });
    expect(listRes.statusCode).toBe(200);
    expect(listRes.json().data.map((c: { id: string }) => c.id)).toContain(complaintId);

    const ownerUser = await prisma.user.findUniqueOrThrow({ where: { clerkId: ownerToken } });
    const assignRes = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgId}/complaints/${complaintId}/assign`,
      headers: auth(ownerToken),
      payload: { assigneeId: ownerUser.id },
    });
    expect(assignRes.statusCode).toBe(200);
    expect(assignRes.json().data.assigneeId).toBe(ownerUser.id);
  });

  it("owner resolves the complaint through valid status transitions, with an audit trail", async () => {
    const toInProgress = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgId}/complaints/${complaintId}/status`,
      headers: auth(ownerToken),
      payload: { status: ComplaintStatus.IN_PROGRESS },
    });
    expect(toInProgress.statusCode).toBe(200);

    const toResolved = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgId}/complaints/${complaintId}/status`,
      headers: auth(ownerToken),
      payload: { status: ComplaintStatus.RESOLVED },
    });
    expect(toResolved.statusCode).toBe(200);
    expect(toResolved.json().data.status).toBe(ComplaintStatus.RESOLVED);
    expect(toResolved.json().data.resolvedAt).toBeTruthy();

    const logs = await withOrgContext(orgId, (tx) =>
      tx.auditLog.findMany({ where: { organizationId: orgId, resource: `complaint:${complaintId}` } })
    );
    expect(logs.length).toBeGreaterThanOrEqual(3); // assign + 2 status transitions
  });

  it("an invalid status transition is rejected", async () => {
    const res = await app.inject({
      method: "PATCH",
      url: `/organizations/${orgId}/complaints/${complaintId}/status`,
      headers: auth(ownerToken),
      payload: { status: ComplaintStatus.IN_PROGRESS }, // RESOLVED -> IN_PROGRESS is not allowed
    });
    expect(res.statusCode).toBe(422);
  });

  it("both owner and tenant can comment on the complaint thread", async () => {
    const ownerComment = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/complaints/${complaintId}/comments`,
      headers: auth(ownerToken),
      payload: { content: "Sent a plumber over, should be fixed now." },
    });
    expect(ownerComment.statusCode).toBe(201);

    const tenantComment = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/tenant/complaints/${complaintId}/comments`,
      headers: auth(tenant1Token),
      payload: { content: "Confirmed, thanks!" },
    });
    expect(tenantComment.statusCode).toBe(201);

    const detail = await app.inject({
      method: "GET",
      url: `/organizations/${orgId}/complaints/${complaintId}`,
      headers: auth(ownerToken),
    });
    expect(detail.json().data.comments).toHaveLength(2);
  });

  it("an ALL_TENANTS notice is visible to every tenant in the property", async () => {
    const createRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/notices`,
      headers: auth(ownerToken),
      payload: { title: "Water supply maintenance", body: "Water will be off 2-4pm tomorrow.", audience: "ALL_TENANTS" },
    });
    expect(createRes.statusCode).toBe(201);

    const [t1Notices, t2Notices] = await Promise.all([
      app.inject({ method: "GET", url: `/organizations/${orgId}/tenant/notices`, headers: auth(tenant1Token) }),
      app.inject({ method: "GET", url: `/organizations/${orgId}/tenant/notices`, headers: auth(tenant2Token) }),
    ]);
    const t1Titles = t1Notices.json().data.map((n: { title: string }) => n.title);
    const t2Titles = t2Notices.json().data.map((n: { title: string }) => n.title);
    expect(t1Titles).toContain("Water supply maintenance");
    expect(t2Titles).toContain("Water supply maintenance");
  });

  it("a FLOOR-targeted notice is visible only to tenants on that floor (the Phase 4 exit criterion)", async () => {
    const createRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/notices`,
      headers: auth(ownerToken),
      payload: { title: "Floor 1 only: fire drill", body: "Fire drill at 10am, floor 1 residents please gather outside.", audience: "FLOOR", floorId: floor1Id },
    });
    expect(createRes.statusCode).toBe(201);

    const [t1Notices, t2Notices] = await Promise.all([
      app.inject({ method: "GET", url: `/organizations/${orgId}/tenant/notices`, headers: auth(tenant1Token) }),
      app.inject({ method: "GET", url: `/organizations/${orgId}/tenant/notices`, headers: auth(tenant2Token) }),
    ]);
    const t1Titles = t1Notices.json().data.map((n: { title: string }) => n.title);
    const t2Titles = t2Notices.json().data.map((n: { title: string }) => n.title);

    expect(t1Titles).toContain("Floor 1 only: fire drill"); // tenant1 is on floor1
    expect(t2Titles).not.toContain("Floor 1 only: fire drill"); // tenant2 is on floor2 (floor2Id)
  });

  it("a ROOM-targeted notice is visible only to tenants in that room", async () => {
    const createRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/notices`,
      headers: auth(ownerToken),
      payload: { title: "Room 201 only: AC repair", body: "AC technician visiting your room at 3pm.", audience: "ROOM", roomId: room2Id },
    });
    expect(createRes.statusCode).toBe(201);

    const [t1Notices, t2Notices] = await Promise.all([
      app.inject({ method: "GET", url: `/organizations/${orgId}/tenant/notices`, headers: auth(tenant1Token) }),
      app.inject({ method: "GET", url: `/organizations/${orgId}/tenant/notices`, headers: auth(tenant2Token) }),
    ]);
    expect(t1Notices.json().data.map((n: { title: string }) => n.title)).not.toContain("Room 201 only: AC repair");
    expect(t2Notices.json().data.map((n: { title: string }) => n.title)).toContain("Room 201 only: AC repair"); // tenant2 is in room2
  });

  it("creating a FLOOR notice without a floorId is rejected", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/notices`,
      headers: auth(ownerToken),
      payload: { title: "Missing floor", body: "x", audience: "FLOOR" },
    });
    expect(res.statusCode).toBe(422);
  });

  it("an already-expired notice is not visible to anyone", async () => {
    const createRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/notices`,
      headers: auth(ownerToken),
      payload: {
        title: "Expired notice",
        body: "x",
        audience: "ALL_TENANTS",
        publishAt: new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString(),
        expiresAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
      },
    });
    expect(createRes.statusCode).toBe(201);

    const t1Notices = await app.inject({ method: "GET", url: `/organizations/${orgId}/tenant/notices`, headers: auth(tenant1Token) });
    expect(t1Notices.json().data.map((n: { title: string }) => n.title)).not.toContain("Expired notice");
  });
});
