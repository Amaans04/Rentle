import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { InvoiceStatus, PaymentStatus } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { HttpError, NotFoundError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";
import { withIdempotency, getIdempotencyKeyHeader } from "../lib/idempotency.js";
import { getPaymentGateway } from "../interfaces/payment-gateway.provider.js";

// No RAZORPAY/CASHFREE here — manual entry only, per plan §3. Those enum
// values exist in the schema for when a live gateway is wired up later.
const manualMethodSchema = z.enum(["CASH", "UPI", "BANK_TRANSFER", "CHEQUE", "WALLET"]);

const recordPaymentSchema = z.object({
  invoiceId: z.string().min(1),
  amount: z.number().positive(),
  method: manualMethodSchema,
  utr: z.string().optional(),
});

export async function paymentRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post(
    "/organizations/:orgId/payments",
    { preHandler: [authenticate, resolveOrg, requirePermission("payment:write")] },
    async (request, reply) => {
      const body = parseOrThrow(recordPaymentSchema, request.body);
      const { organization, member } = request.orgContext!;

      const result = await withIdempotency(organization.id, getIdempotencyKeyHeader(request.headers), async () => {
        const payment = await withRequestOrgContext(request, async (tx) => {
          const invoice = await tx.invoice.findFirst({
            where: { id: body.invoiceId, organizationId: organization.id },
          });
          if (!invoice) throw new NotFoundError("Invoice");
          if (invoice.status === InvoiceStatus.VOID || invoice.status === InvoiceStatus.REFUNDED) {
            throw new HttpError(409, "CONFLICT", `Invoice is ${invoice.status}, cannot record a payment against it.`);
          }

          const remaining = Number(invoice.totalAmount) - Number(invoice.paidAmount);
          if (body.amount > remaining) {
            throw new HttpError(
              422,
              "AMOUNT_EXCEEDS_BALANCE",
              `Payment of ${body.amount} exceeds the remaining balance of ${remaining} on this invoice.`
            );
          }

          const gateway = getPaymentGateway();
          const { externalId } = await gateway.recordManualPayment({
            tenancyId: invoice.tenancyId,
            amount: body.amount,
            method: body.method,
            utr: body.utr,
          });

          return withAudit(
            tx,
            { organizationId: organization.id, userId: member.userId, action: "PAYMENT", resource: "payment" },
            async () => {
              const created = await tx.payment.create({
                data: {
                  organizationId: organization.id,
                  propertyId: invoice.propertyId,
                  tenancyId: invoice.tenancyId,
                  amount: body.amount,
                  method: body.method,
                  status: PaymentStatus.SUCCEEDED,
                  externalId: externalId ?? undefined,
                  utr: body.utr,
                  paidAt: new Date(),
                  allocations: {
                    create: [{ invoiceId: invoice.id, amount: body.amount }],
                  },
                },
              });

              const newPaidAmount = Number(invoice.paidAmount) + body.amount;
              await tx.invoice.update({
                where: { id: invoice.id },
                data: {
                  paidAmount: newPaidAmount,
                  status: newPaidAmount >= Number(invoice.totalAmount) ? InvoiceStatus.PAID : InvoiceStatus.PARTIALLY_PAID,
                  version: { increment: 1 },
                },
              });

              return created;
            }
          );
        });

        return { statusCode: 201, body: ok(payment) };
      });

      return reply.status(result.statusCode).send(result.body);
    }
  );

  fastify.get(
    "/organizations/:orgId/properties/:propertyId/payments",
    { preHandler: [authenticate, resolveOrg, requirePermission("payment:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const payments = await withRequestOrgContext(request, (tx) =>
        tx.payment.findMany({
          where: { propertyId, organizationId: organization.id },
          include: { allocations: { include: { invoice: true } } },
          orderBy: { paidAt: "desc" },
        })
      );
      return reply.status(200).send(ok(payments));
    }
  );
}
