import type { FastifyInstance } from "fastify";
import { prisma } from "../lib/prisma.js";
import { ok } from "../lib/api-response.js";
import { authenticate } from "../auth/pipeline.js";

/** First call the app makes post-login: who am I, and what orgs am I in. */
export async function meRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.get("/me", { preHandler: [authenticate] }, async (request, reply) => {
    const memberships = await prisma.organizationMember.findMany({
      where: { userId: request.authUser!.id, isActive: true, deletedAt: null },
      include: { organization: true },
    });

    return reply.status(200).send(
      ok({
        user: request.authUser,
        memberships: memberships.map((m) => ({
          organizationId: m.organizationId,
          organizationName: m.organization.name,
          role: m.role,
          propertyIds: m.propertyIds,
        })),
      })
    );
  });
}
