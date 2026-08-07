import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { OrgMemberRole } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { HttpError, NotFoundError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";
import { clerkClient } from "../auth/clerk.js";

const inviteSchema = z.object({
  email: z.string().email(),
  // The role/propertyIds we INTEND this person to have — recorded now for
  // the audit trail, applied via PATCH /members/:memberId once they've
  // actually joined (Clerk's own invitation role is a coarse org:member,
  // never used to carry our granular business role — see clerk.ts).
  intendedRole: z.nativeEnum(OrgMemberRole).default(OrgMemberRole.STAFF),
  intendedPropertyIds: z.array(z.string()).default([]),
});

const staffProfileSchema = z.object({
  salary: z.number().nonnegative().optional(),
  joinDate: z.coerce.date().optional(),
});

export async function staffRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post(
    "/organizations/:orgId/staff/invite",
    { preHandler: [authenticate, resolveOrg, requirePermission("staff:write")] },
    async (request, reply) => {
      const body = parseOrThrow(inviteSchema, request.body);
      const { organization, member: actor } = request.orgContext!;

      let invitation;
      try {
        invitation = await clerkClient.organizations.createOrganizationInvitation({
          organizationId: organization.clerkOrgId,
          emailAddress: body.email,
          role: "org:member",
          inviterUserId: request.authUser!.clerkId,
        });
      } catch (err) {
        throw new HttpError(502, "CLERK_ERROR", "Failed to send invitation via Clerk.", (err as Error).message);
      }

      await withRequestOrgContext(request, (tx) =>
        withAudit(
          tx,
          {
            organizationId: organization.id,
            userId: actor.userId,
            action: "CREATE",
            resource: "staff-invite",
            metadata: { email: body.email, intendedRole: body.intendedRole, intendedPropertyIds: body.intendedPropertyIds },
          },
          async () => null
        )
      );

      return reply.status(202).send(ok({ invitationId: invitation.id, email: body.email, status: invitation.status }));
    }
  );

  fastify.put(
    "/organizations/:orgId/members/:memberId/staff-profile",
    { preHandler: [authenticate, resolveOrg, requirePermission("staff:write")] },
    async (request, reply) => {
      const { memberId } = parseOrThrow(z.object({ memberId: z.string().min(1) }), request.params);
      const body = parseOrThrow(staffProfileSchema, request.body);
      const { organization, member: actor } = request.orgContext!;

      const profile = await withRequestOrgContext(request, async (tx) => {
        const targetMember = await tx.organizationMember.findFirst({
          where: { id: memberId, organizationId: organization.id, deletedAt: null },
        });
        if (!targetMember) throw new NotFoundError("Member");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: actor.userId, action: "UPDATE", resource: `staff-profile:${memberId}` },
          () =>
            tx.staffProfile.upsert({
              where: { memberId },
              create: { memberId, ...body },
              update: body,
            })
        );
      });

      return reply.status(200).send(ok(profile));
    }
  );

  fastify.get(
    "/organizations/:orgId/members/:memberId/staff-profile",
    { preHandler: [authenticate, resolveOrg, requirePermission("staff:read")] },
    async (request, reply) => {
      const { memberId } = parseOrThrow(z.object({ memberId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const profile = await withRequestOrgContext(request, (tx) => tx.staffProfile.findUnique({ where: { memberId } }));
      if (!profile) throw new NotFoundError("Staff profile");

      // Belt-and-suspenders: staffProfile has no organizationId of its own
      // (it's one hop from organization_members, same pattern as rls.sql's
      // child-table policies), so re-verify the parent member's org here too.
      const memberBelongsToOrg = await withRequestOrgContext(request, (tx) =>
        tx.organizationMember.findFirst({ where: { id: memberId, organizationId: organization.id, deletedAt: null } })
      );
      if (!memberBelongsToOrg) throw new NotFoundError("Staff profile");

      return reply.status(200).send(ok(profile));
    }
  );
}
