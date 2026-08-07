import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { OrgMemberRole, type Prisma } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { NotFoundError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";

const updateOrgSchema = z.object({
  name: z.string().min(1).optional(),
  logoUrl: z.string().url().nullable().optional(),
  primaryColor: z.string().optional(),
  timezone: z.string().optional(),
  currency: z.string().optional(),
  gstin: z.string().nullable().optional(),
  settings: z.record(z.string(), z.unknown()).optional(),
});

const updateMemberSchema = z.object({
  role: z.nativeEnum(OrgMemberRole).optional(),
  propertyIds: z.array(z.string()).optional(),
  isActive: z.boolean().optional(),
});

export async function organizationRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.get(
    "/organizations/:orgId",
    { preHandler: [authenticate, resolveOrg, requirePermission("organization:read")] },
    async (request, reply) => {
      return reply.status(200).send(ok(request.orgContext!.organization));
    }
  );

  fastify.patch(
    "/organizations/:orgId",
    { preHandler: [authenticate, resolveOrg, requirePermission("organization:write")] },
    async (request, reply) => {
      const body = parseOrThrow(updateOrgSchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, (tx) =>
        withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `organization:${organization.id}` },
          () =>
            tx.organization.update({
              where: { id: organization.id },
              data: { ...body, settings: body.settings as Prisma.InputJsonValue | undefined },
            })
        )
      );

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.get(
    "/organizations/:orgId/members",
    { preHandler: [authenticate, resolveOrg, requirePermission("member:read")] },
    async (request, reply) => {
      const { organization } = request.orgContext!;
      const members = await withRequestOrgContext(request, (tx) =>
        tx.organizationMember.findMany({
          where: { organizationId: organization.id, deletedAt: null },
          include: { user: { select: { id: true, name: true, email: true, phone: true, avatarUrl: true } } },
          orderBy: { createdAt: "asc" },
        })
      );
      return reply.status(200).send(ok(members));
    }
  );

  fastify.patch(
    "/organizations/:orgId/members/:memberId",
    { preHandler: [authenticate, resolveOrg, requirePermission("member:write")] },
    async (request, reply) => {
      const { memberId } = parseOrThrow(z.object({ memberId: z.string().min(1) }), request.params);
      const body = parseOrThrow(updateMemberSchema, request.body);
      const { organization, member: actor } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        // Ownership re-derivation: the member must belong to THIS org, never trust the
        // path param alone — the direct fix for the admin-login.js bug class.
        const existing = await tx.organizationMember.findFirst({
          where: { id: memberId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Member");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: actor.userId, action: "UPDATE", resource: `member:${memberId}` },
          () => tx.organizationMember.update({ where: { id: memberId }, data: body })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.delete(
    "/organizations/:orgId/members/:memberId",
    { preHandler: [authenticate, resolveOrg, requirePermission("member:write")] },
    async (request, reply) => {
      const { memberId } = parseOrThrow(z.object({ memberId: z.string().min(1) }), request.params);
      const { organization, member: actor } = request.orgContext!;

      await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.organizationMember.findFirst({
          where: { id: memberId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Member");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: actor.userId, action: "DELETE", resource: `member:${memberId}` },
          () =>
            tx.organizationMember.update({
              where: { id: memberId },
              data: { isActive: false, deletedAt: new Date() },
            })
        );
      });

      return reply.status(204).send();
    }
  );
}
