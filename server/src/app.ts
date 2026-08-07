import Fastify, { type FastifyError, type FastifyInstance } from "fastify";
import rateLimit from "@fastify/rate-limit";
import { clerkWebhookRoutes } from "./routes/webhooks/clerk.js";
import { internalHealthRoutes } from "./routes/internal/health.js";
import { internalInvoiceRoutes } from "./routes/internal/invoices.js";
import { meRoutes } from "./routes/me.js";
import { organizationRoutes } from "./routes/organizations.js";
import { propertyRoutes } from "./routes/properties.js";
import { buildingFloorRoutes } from "./routes/buildings-floors.js";
import { roomBedRoutes } from "./routes/rooms-beds.js";
import { staffRoutes } from "./routes/staff.js";
import { tenancyRoutes } from "./routes/tenancies.js";
import { tenantSelfRoutes } from "./routes/tenant.js";
import { invoiceRoutes } from "./routes/invoices.js";
import { paymentRoutes } from "./routes/payments.js";
import { complaintRoutes } from "./routes/complaints.js";
import { noticeRoutes } from "./routes/notices.js";
import { fail } from "./lib/api-response.js";
import { HttpError } from "./lib/http-errors.js";

/**
 * Split from index.ts so tests can build the app without binding a port.
 */
export function buildApp(): FastifyInstance {
  const app = Fastify({
    logger: process.env.NODE_ENV !== "test",
  });

  app.register(rateLimit, {
    max: 100,
    timeWindow: "1 minute",
  });

  app.setErrorHandler((error: FastifyError | HttpError, _request, reply) => {
    if (error instanceof HttpError) {
      return reply.status(error.statusCode).send(fail(error.code, error.message, error.details));
    }
    // Fastify's own validation/parsing errors (e.g. malformed JSON body) carry a statusCode too.
    if (typeof error.statusCode === "number" && error.statusCode < 500) {
      return reply.status(error.statusCode).send(fail("BAD_REQUEST", error.message));
    }
    app.log.error(error);
    reply.status(500).send(fail("INTERNAL_ERROR", "Something went wrong."));
  });

  // Public, unauthenticated liveness check for Render's own health probing —
  // deliberately separate from /internal/health, which requires a secret
  // and does a real DB round-trip (used by the daily cron as a Supabase
  // keep-alive, not suitable as an infra-level liveness probe).
  app.get("/health", async (_request, reply) => reply.status(200).send({ status: "ok" }));

  app.register(clerkWebhookRoutes);
  app.register(internalHealthRoutes);
  app.register(internalInvoiceRoutes);
  app.register(meRoutes);
  app.register(organizationRoutes);
  app.register(propertyRoutes);
  app.register(buildingFloorRoutes);
  app.register(roomBedRoutes);
  app.register(staffRoutes);
  app.register(tenancyRoutes);
  app.register(tenantSelfRoutes);
  app.register(invoiceRoutes);
  app.register(paymentRoutes);
  app.register(complaintRoutes);
  app.register(noticeRoutes);

  return app;
}
