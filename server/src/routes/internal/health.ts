import type { FastifyInstance } from "fastify";
import { env } from "../../lib/env.js";
import { prisma } from "../../lib/prisma.js";
import { ok, fail } from "../../lib/api-response.js";

/**
 * Used by the GitHub Actions daily workflow as a Supabase keep-alive ping
 * (a real query against the DB, not just a process-alive check) — see
 * .github/workflows/daily-jobs.yml. Protected by a shared secret rather than
 * Clerk auth since it's called machine-to-machine, not by a logged-in user.
 */
export async function internalHealthRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.get("/internal/health", async (request, reply) => {
    const provided = request.headers["x-internal-secret"];
    if (provided !== env.INTERNAL_CRON_SECRET) {
      return reply.status(401).send(fail("UNAUTHORIZED", "Authentication required."));
    }

    await prisma.$queryRaw`SELECT 1`;
    return reply.status(200).send(ok({ status: "ok", timestamp: new Date().toISOString() }));
  });
}
