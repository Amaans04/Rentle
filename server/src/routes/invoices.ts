import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { InvoiceStatus } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { NotFoundError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withIdempotency, getIdempotencyKeyHeader } from "../lib/idempotency.js";
import { generateInvoicesForProperty } from "../services/invoicing.js";

const generateSchema = z.object({
  year: z.number().int().min(2020).max(2100).optional(),
  month: z.number().int().min(1).max(12).optional(),
});

export async function invoiceRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post(
    "/organizations/:orgId/properties/:propertyId/invoices/generate",
    { preHandler: [authenticate, resolveOrg, requirePermission("invoice:write")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(generateSchema, request.body ?? {});
      const { organization, member } = request.orgContext!;

      const now = new Date();
      const year = body.year ?? now.getUTCFullYear();
      const month = body.month ?? now.getUTCMonth() + 1;

      const result = await withIdempotency(organization.id, getIdempotencyKeyHeader(request.headers), async () => {
        const invoices = await withRequestOrgContext(request, (tx) =>
          generateInvoicesForProperty(tx, { organizationId: organization.id, propertyId, year, month, actorUserId: member.userId })
        );
        return { statusCode: 201, body: ok({ generated: invoices.length, invoices }) };
      });

      return reply.status(result.statusCode).send(result.body);
    }
  );

  fastify.get(
    "/organizations/:orgId/properties/:propertyId/invoices",
    { preHandler: [authenticate, resolveOrg, requirePermission("invoice:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { status } = parseOrThrow(z.object({ status: z.nativeEnum(InvoiceStatus).optional() }), request.query);
      const { organization } = request.orgContext!;

      const invoices = await withRequestOrgContext(request, (tx) =>
        tx.invoice.findMany({
          where: { propertyId, organizationId: organization.id, ...(status ? { status } : {}) },
          include: { lineItems: true },
          orderBy: { dueDate: "desc" },
        })
      );
      return reply.status(200).send(ok(invoices));
    }
  );

  fastify.get(
    "/organizations/:orgId/invoices/:invoiceId",
    { preHandler: [authenticate, resolveOrg, requirePermission("invoice:read")] },
    async (request, reply) => {
      const { invoiceId } = parseOrThrow(z.object({ invoiceId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const invoice = await withRequestOrgContext(request, (tx) =>
        tx.invoice.findFirst({
          where: { id: invoiceId, organizationId: organization.id },
          include: { lineItems: true, allocations: { include: { payment: true } } },
        })
      );
      if (!invoice) throw new NotFoundError("Invoice");

      return reply.status(200).send(ok(invoice));
    }
  );
}
