import Fastify, { type FastifyError, type FastifyInstance } from "fastify";
import rateLimit from "@fastify/rate-limit";
import { clerkWebhookRoutes } from "./routes/webhooks/clerk.js";
import { internalHealthRoutes } from "./routes/internal/health.js";
import { meRoutes } from "./routes/me.js";
import { fail } from "./lib/api-response.js";

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

  app.setErrorHandler((error: FastifyError, _request, reply) => {
    app.log.error(error);
    reply.status(error.statusCode ?? 500).send(fail("INTERNAL_ERROR", "Something went wrong."));
  });

  // Public, unauthenticated liveness check for Render's own health probing —
  // deliberately separate from /internal/health, which requires a secret
  // and does a real DB round-trip (used by the daily cron as a Supabase
  // keep-alive, not suitable as an infra-level liveness probe).
  app.get("/health", async (_request, reply) => reply.status(200).send({ status: "ok" }));

  app.register(clerkWebhookRoutes);
  app.register(internalHealthRoutes);
  app.register(meRoutes);

  // Phase 1+ resource routes (organizations, properties, rooms, beds,
  // tenancies, invoices, payments, complaints, notices, staff) register
  // here as they're built.

  return app;
}
