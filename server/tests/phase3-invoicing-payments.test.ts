import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { OrgMemberRole, TenancyStatus, InvoiceStatus, PropertyType } from "@prisma/client";
import { withOrgContext } from "../src/auth/db-context.js";
import { prisma } from "../src/lib/prisma.js";
import { sweepStaleTestData } from "./sweep-stale-test-data.js";
import { computeDueDate, computeInvoicePeriod } from "../src/services/invoicing.js";

/**
 * Exercises the Phase 3 exit criteria: monthly invoices generate with
 * correct due-date/grace-period math; a cash payment updates
 * paidAmount/status correctly; an idempotency key prevents double
 * recording; the internal cron endpoint works end to end (the GitHub
 * Actions schedule itself firing is out of scope for a test — that's
 * verified by watching the workflow run for real, see docs/PROGRESS.md).
 */
vi.mock("../src/auth/clerk.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/auth/clerk.js")>();
  return {
    ...actual,
    verifyClerkToken: vi.fn(async (token: string) => ({ clerkUserId: token })),
  };
});

const hasLiveDb = process.env.RUN_DB_TESTS === "true";

describe.skipIf(!hasLiveDb)("Phase 3: invoicing + manual payments", () => {
  let buildApp: typeof import("../src/app.js").buildApp;
  let app: import("fastify").FastifyInstance;

  let orgId: string;
  let ownerToken: string;
  let propertyId: string;
  let tenancyId: string;
  let rentAmount: number;
  const rentDueDay = 5;
  const gracePeriodDays = 3;

  // A separate, already-overdue tenancy to exercise the grace-period branch.
  let overdueTenancyId: string;

  function auth(token: string) {
    return { authorization: `Bearer ${token}` };
  }

  beforeAll(async () => {
    ({ buildApp } = await import("../src/app.js"));
    app = buildApp();
    await sweepStaleTestData();

    const suffix = Date.now();
    ownerToken = `test_owner_p3_${suffix}`;
    const owner = await prisma.user.create({ data: { clerkId: ownerToken, email: `${ownerToken}@test.local` } });

    const org = await prisma.organization.create({
      data: { clerkOrgId: `test_org_p3_${suffix}`, name: "Org P3", slug: `org-p3-${suffix}` },
    });
    orgId = org.id;
    await prisma.organizationMember.create({ data: { organizationId: orgId, userId: owner.id, role: OrgMemberRole.OWNER } });

    await withOrgContext(orgId, async (tx) => {
      const property = await tx.property.create({
        data: {
          organizationId: orgId,
          name: "P3 Test PG",
          slug: `p3-test-pg-${suffix}`,
          type: PropertyType.PG,
          rentDueDay,
          gracePeriodDays,
          address: { line1: "x", city: "x", state: "x", pincode: "000000" },
        },
      });
      propertyId = property.id;
      const building = await tx.building.create({ data: { propertyId, organizationId: orgId, name: "Main" } });
      const floor = await tx.floor.create({ data: { buildingId: building.id, organizationId: orgId, name: "1", level: 1 } });
      const room = await tx.room.create({
        data: { propertyId, floorId: floor.id, organizationId: orgId, roomNumber: "101", rentAmount: 9500, mrpAmount: 10000 },
      });
      const bed = await tx.bed.create({ data: { roomId: room.id, propertyId, organizationId: orgId, bedLabel: "A", status: "OCCUPIED" } });
      const tenantUser = await tx.user.create({ data: { clerkId: `test_tenant_p3_${suffix}`, email: `test_tenant_p3_${suffix}@test.local` } });
      rentAmount = 9500;
      const tenancy = await tx.tenancy.create({
        data: {
          organizationId: orgId,
          propertyId,
          bedId: bed.id,
          userId: tenantUser.id,
          status: TenancyStatus.ACTIVE,
          rentAmount,
          moveInDate: new Date(),
        },
      });
      tenancyId = tenancy.id;

      // Second bed/tenant for the grace-period test.
      const bed2 = await tx.bed.create({ data: { roomId: room.id, propertyId, organizationId: orgId, bedLabel: "B", status: "OCCUPIED" } });
      const tenantUser2 = await tx.user.create({ data: { clerkId: `test_tenant2_p3_${suffix}`, email: `test_tenant2_p3_${suffix}@test.local` } });
      const tenancy2 = await tx.tenancy.create({
        data: {
          organizationId: orgId,
          propertyId,
          bedId: bed2.id,
          userId: tenantUser2.id,
          status: TenancyStatus.ACTIVE,
          rentAmount,
          moveInDate: new Date(),
        },
      });
      overdueTenancyId = tenancy2.id;
    });
  });

  afterAll(async () => {
    await withOrgContext(orgId, (tx) => tx.idempotencyKey.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.auditLog.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.paymentAllocation.deleteMany({ where: { payment: { organizationId: orgId } } }));
    await withOrgContext(orgId, (tx) => tx.payment.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.invoiceLineItem.deleteMany({ where: { invoice: { organizationId: orgId } } }));
    await withOrgContext(orgId, (tx) => tx.invoice.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.tenancy.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.bed.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.room.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.floor.deleteMany({ where: { organizationId: orgId } }));
    await withOrgContext(orgId, (tx) => tx.building.deleteMany({ where: { organizationId: orgId } }));
    await prisma.propertyListing.deleteMany({ where: { organizationId: orgId } });
    await withOrgContext(orgId, (tx) => tx.property.deleteMany({ where: { organizationId: orgId } }));
    await prisma.organizationMember.deleteMany({ where: { organizationId: orgId } });
    const tenantUsers = await prisma.user.findMany({ where: { clerkId: { startsWith: "test_tenant" } }, select: { id: true } });
    await prisma.user.deleteMany({ where: { id: { in: tenantUsers.map((u) => u.id) } } });
    await prisma.organization.deleteMany({ where: { id: orgId } });
    await prisma.user.deleteMany({ where: { clerkId: ownerToken } });
    await app.close();
  });

  let generatedInvoiceId: string;

  it("generates a monthly invoice with correct due-date math", async () => {
    const now = new Date();
    const year = now.getUTCFullYear();
    const month = now.getUTCMonth() + 1;

    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/invoices/generate`,
      headers: auth(ownerToken),
      payload: { year, month },
    });
    expect(res.statusCode).toBe(201);
    const { generated, invoices } = res.json().data;
    expect(generated).toBe(2); // both ACTIVE tenancies get one each

    const invoice = invoices.find((inv: { tenancyId: string }) => inv.tenancyId === tenancyId);
    generatedInvoiceId = invoice.id;

    const expectedDueDate = computeDueDate(rentDueDay, year, month);
    expect(new Date(invoice.dueDate).toISOString().slice(0, 10)).toBe(expectedDueDate.toISOString().slice(0, 10));

    const { periodStart, periodEnd } = computeInvoicePeriod(year, month);
    expect(new Date(invoice.periodStart).toISOString().slice(0, 10)).toBe(periodStart.toISOString().slice(0, 10));
    expect(new Date(invoice.periodEnd).toISOString().slice(0, 10)).toBe(periodEnd.toISOString().slice(0, 10));

    expect(Number(invoice.totalAmount)).toBe(rentAmount);
  });

  it("re-running generate for the same period is a safe no-op (domain-level dedup)", async () => {
    const now = new Date();
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/invoices/generate`,
      headers: auth(ownerToken),
      payload: { year: now.getUTCFullYear(), month: now.getUTCMonth() + 1 },
    });
    expect(res.statusCode).toBe(201);
    expect(res.json().data.generated).toBe(0);
  });

  it("a past period past its grace window generates an OVERDUE invoice", async () => {
    // A period far enough in the past that dueDate + gracePeriodDays has
    // definitely elapsed, regardless of what day "now" happens to be.
    const now = new Date();
    let year = now.getUTCFullYear();
    let month = now.getUTCMonth() + 1 - 2; // two months back
    if (month < 1) {
      month += 12;
      year -= 1;
    }

    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/invoices/generate`,
      headers: auth(ownerToken),
      payload: { year, month },
    });
    expect(res.statusCode).toBe(201);
    const invoice = res.json().data.invoices.find((inv: { tenancyId: string }) => inv.tenancyId === overdueTenancyId);
    expect(invoice.status).toBe(InvoiceStatus.OVERDUE);
  });

  it("recording a partial cash payment updates paidAmount and status to PARTIALLY_PAID", async () => {
    const partial = Math.floor(rentAmount / 2);
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/payments`,
      headers: auth(ownerToken),
      payload: { invoiceId: generatedInvoiceId, amount: partial, method: "CASH" },
    });
    expect(res.statusCode).toBe(201);

    const invoice = await withOrgContext(orgId, (tx) => tx.invoice.findUniqueOrThrow({ where: { id: generatedInvoiceId } }));
    expect(Number(invoice.paidAmount)).toBe(partial);
    expect(invoice.status).toBe(InvoiceStatus.PARTIALLY_PAID);
  });

  it("paying the remaining balance moves the invoice to PAID", async () => {
    const invoiceBefore = await withOrgContext(orgId, (tx) => tx.invoice.findUniqueOrThrow({ where: { id: generatedInvoiceId } }));
    const remaining = Number(invoiceBefore.totalAmount) - Number(invoiceBefore.paidAmount);

    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/payments`,
      headers: auth(ownerToken),
      payload: { invoiceId: generatedInvoiceId, amount: remaining, method: "UPI" },
    });
    expect(res.statusCode).toBe(201);

    const invoiceAfter = await withOrgContext(orgId, (tx) => tx.invoice.findUniqueOrThrow({ where: { id: generatedInvoiceId } }));
    expect(Number(invoiceAfter.paidAmount)).toBe(Number(invoiceBefore.totalAmount));
    expect(invoiceAfter.status).toBe(InvoiceStatus.PAID);
  });

  it("overpaying a fully-paid invoice is rejected", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/payments`,
      headers: auth(ownerToken),
      payload: { invoiceId: generatedInvoiceId, amount: 100, method: "CASH" },
    });
    expect(res.statusCode).toBe(422);
  });

  it("a live-gateway method (RAZORPAY) is rejected by validation — manual entry only", async () => {
    const res = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/payments`,
      headers: auth(ownerToken),
      payload: { invoiceId: generatedInvoiceId, amount: 100, method: "RAZORPAY" },
    });
    expect(res.statusCode).toBe(400);
  });

  it("an Idempotency-Key prevents a payment from being recorded twice", async () => {
    // A fresh unpaid invoice so this test doesn't depend on the exact
    // remaining balance left by earlier tests.
    const now = new Date();
    let month = now.getUTCMonth() + 1 - 1;
    let year = now.getUTCFullYear();
    if (month < 1) {
      month += 12;
      year -= 1;
    }
    const genRes = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/properties/${propertyId}/invoices/generate`,
      headers: auth(ownerToken),
      payload: { year, month },
    });
    const freshInvoice = genRes.json().data.invoices.find((inv: { tenancyId: string }) => inv.tenancyId === tenancyId);

    const idempotencyKey = `test-idem-key-${Date.now()}`;
    const payload = { invoiceId: freshInvoice.id, amount: 500, method: "CASH" };

    const first = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/payments`,
      headers: { ...auth(ownerToken), "idempotency-key": idempotencyKey },
      payload,
    });
    expect(first.statusCode).toBe(201);

    const second = await app.inject({
      method: "POST",
      url: `/organizations/${orgId}/payments`,
      headers: { ...auth(ownerToken), "idempotency-key": idempotencyKey },
      payload,
    });
    expect(second.statusCode).toBe(201);
    expect(second.json().data.id).toBe(first.json().data.id); // same cached response, not a new Payment

    const payments = await withOrgContext(orgId, (tx) => tx.payment.findMany({ where: { organizationId: orgId, tenancyId } }));
    const matchingPayments = payments.filter((p) => Number(p.amount) === 500);
    expect(matchingPayments).toHaveLength(1); // not double-recorded
  });

  it("the internal cron endpoint requires the shared secret", async () => {
    const noAuthRes = await app.inject({ method: "POST", url: "/internal/invoices/generate" });
    expect(noAuthRes.statusCode).toBe(401);
  });

  it("the internal cron endpoint generates across all organizations when authorized", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/internal/invoices/generate",
      headers: { "x-internal-secret": process.env.INTERNAL_CRON_SECRET! },
    });
    expect(res.statusCode).toBe(200);
    expect(typeof res.json().data.totalGenerated).toBe("number");
  });
});
