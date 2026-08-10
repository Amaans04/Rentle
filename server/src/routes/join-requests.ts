import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { BedStatus, JoinRequestStatus, TenancyStatus } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { NotFoundError, ConflictError } from "../lib/http-errors.js";
import { orgIdParamSchema, parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withOrgContext } from "../auth/db-context.js";
import { prisma } from "../lib/prisma.js";
import { withAudit } from "../lib/with-audit.js";

const searchSchema = z.object({ q: z.string().min(1).max(100) });
const createJoinRequestSchema = z.object({
  propertyId: z.string().min(1),
  message: z.string().max(500).optional(),
});
const respondSchema = z.object({ note: z.string().max(500).optional() });
const approveSchema = z.object({
  bedId: z.string().min(1),
  rentAmount: z.number().nonnegative(),
  depositAmount: z.number().nonnegative().default(0),
  note: z.string().max(500).optional(),
});
const requestIdParamSchema = z.object({ orgId: z.string().min(1), requestId: z.string().min(1) });

export async function joinRequestRoutes(fastify: FastifyInstance): Promise<void> {
  /**
   * Public-ish search — the one place any authenticated user can read across
   * every org. Only ever queries `property_listings`, the narrow non-RLS
   * projection (see its model comment in schema.prisma) — never touches the
   * RLS-protected `properties` table directly, so this can't leak anything
   * beyond name/city/state no matter what q is.
   */
  fastify.get("/property-listings/search", { preHandler: [authenticate] }, async (request, reply) => {
    const { q } = parseOrThrow(searchSchema, request.query);

    const listings = await prisma.propertyListing.findMany({
      where: { OR: [{ name: { contains: q, mode: "insensitive" } }, { city: { contains: q, mode: "insensitive" } }] },
      orderBy: { name: "asc" },
      take: 20,
    });

    return reply.status(200).send(ok(listings));
  });

  /**
   * Tenant creates a request — runs BEFORE any membership/tenancy exists,
   * same structural shape as tenant.ts's onboarding/accept: only
   * `authenticate`, then the org is validated explicitly (organizations
   * has no RLS, see rls.sql) before opening a withOrgContext transaction
   * scoped to that now-verified org id. propertyId is re-validated against
   * the real `properties` table inside that transaction — the client only
   * ever supplies an id it got from the public search results, never trust
   * beyond that.
   */
  fastify.post(
    "/organizations/:orgId/join-requests",
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { orgId } = parseOrThrow(orgIdParamSchema, request.params);
      const body = parseOrThrow(createJoinRequestSchema, request.body);

      const organization = await prisma.organization.findUnique({ where: { id: orgId } });
      if (!organization || organization.deletedAt) throw new NotFoundError("Organization");

      const created = await withOrgContext(orgId, async (tx) => {
        const property = await tx.property.findFirst({
          where: { id: body.propertyId, organizationId: orgId, deletedAt: null },
        });
        if (!property) throw new NotFoundError("Property");

        const existingTenancy = await tx.tenancy.findFirst({
          where: {
            organizationId: orgId,
            userId: request.authUser!.id,
            deletedAt: null,
            status: { not: TenancyStatus.ARCHIVED },
          },
        });
        if (existingTenancy) {
          throw new ConflictError("You already have an active or pending tenancy in this organization.");
        }

        const existingRequest = await tx.joinRequest.findFirst({
          where: { organizationId: orgId, userId: request.authUser!.id, status: JoinRequestStatus.PENDING },
        });
        if (existingRequest) {
          throw new ConflictError("You already have a pending request for this organization.");
        }

        return tx.joinRequest.create({
          data: {
            organizationId: orgId,
            propertyId: property.id,
            userId: request.authUser!.id,
            message: body.message,
          },
        });
      });

      return reply.status(201).send(ok(created));
    }
  );

  /** Tenant polls their own requests for one org — never a cross-org list. */
  fastify.get(
    "/organizations/:orgId/join-requests/mine",
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { orgId } = parseOrThrow(orgIdParamSchema, request.params);

      const organization = await prisma.organization.findUnique({ where: { id: orgId } });
      if (!organization || organization.deletedAt) throw new NotFoundError("Organization");

      const requests = await withOrgContext(orgId, (tx) =>
        tx.joinRequest.findMany({
          where: { organizationId: orgId, userId: request.authUser!.id },
          include: { property: { select: { id: true, name: true } } },
          orderBy: { createdAt: "desc" },
        })
      );

      return reply.status(200).send(ok(requests));
    }
  );

  /** Tenant withdraws their own still-pending request. */
  fastify.patch(
    "/organizations/:orgId/join-requests/:requestId/cancel",
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { orgId, requestId } = parseOrThrow(requestIdParamSchema, request.params);

      const organization = await prisma.organization.findUnique({ where: { id: orgId } });
      if (!organization || organization.deletedAt) throw new NotFoundError("Organization");

      const updated = await withOrgContext(orgId, async (tx) => {
        const joinRequest = await tx.joinRequest.findFirst({
          where: { id: requestId, organizationId: orgId, userId: request.authUser!.id },
        });
        if (!joinRequest) throw new NotFoundError("Join request");
        if (joinRequest.status !== JoinRequestStatus.PENDING) {
          throw new ConflictError(`Request is already ${joinRequest.status.toLowerCase()}.`);
        }

        return tx.joinRequest.update({ where: { id: requestId }, data: { status: JoinRequestStatus.CANCELLED } });
      });

      return reply.status(200).send(ok(updated));
    }
  );

  // --- Owner side ---

  fastify.get(
    "/organizations/:orgId/join-requests",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:read")] },
    async (request, reply) => {
      const { status } = parseOrThrow(z.object({ status: z.nativeEnum(JoinRequestStatus).optional() }), request.query);
      const { organization } = request.orgContext!;

      const requests = await withRequestOrgContext(request, (tx) =>
        tx.joinRequest.findMany({
          where: { organizationId: organization.id, ...(status ? { status } : {}) },
          include: {
            user: { select: { id: true, name: true, email: true, phone: true } },
            property: { select: { id: true, name: true } },
          },
          orderBy: { createdAt: "desc" },
        })
      );

      return reply.status(200).send(ok(requests));
    }
  );

  fastify.patch(
    "/organizations/:orgId/join-requests/:requestId/reject",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:write")] },
    async (request, reply) => {
      const { requestId } = parseOrThrow(z.object({ requestId: z.string().min(1) }), request.params);
      const body = parseOrThrow(respondSchema, request.body ?? {});
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const joinRequest = await tx.joinRequest.findFirst({
          where: { id: requestId, organizationId: organization.id },
        });
        if (!joinRequest) throw new NotFoundError("Join request");
        if (joinRequest.status !== JoinRequestStatus.PENDING) {
          throw new ConflictError(`Request is already ${joinRequest.status.toLowerCase()}.`);
        }

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `join-request:${requestId}` },
          () =>
            tx.joinRequest.update({
              where: { id: requestId },
              data: { status: JoinRequestStatus.REJECTED, respondedBy: member.userId, responseNote: body.note },
            })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  /**
   * Approve collapses what a cold invite needs two round trips for (owner
   * invites → tenant separately accepts) into one, because the tenant's
   * identity and consent are already established by the request itself —
   * no signed onboarding token needed, straight to a real Tenancy row in
   * the same PENDING_ONBOARDING state accept() would leave it in. Reuses
   * the exact same bed-reservation and VACANT check as tenancies.ts'
   * /invite so the two paths can never diverge in bed-status handling.
   */
  fastify.patch(
    "/organizations/:orgId/join-requests/:requestId/approve",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:write")] },
    async (request, reply) => {
      const { requestId } = parseOrThrow(z.object({ requestId: z.string().min(1) }), request.params);
      const body = parseOrThrow(approveSchema, request.body);
      const { organization, member } = request.orgContext!;

      const result = await withRequestOrgContext(request, async (tx) => {
        const joinRequest = await tx.joinRequest.findFirst({
          where: { id: requestId, organizationId: organization.id },
        });
        if (!joinRequest) throw new NotFoundError("Join request");
        if (joinRequest.status !== JoinRequestStatus.PENDING) {
          throw new ConflictError(`Request is already ${joinRequest.status.toLowerCase()}.`);
        }

        const bed = await tx.bed.findFirst({
          where: { id: body.bedId, propertyId: joinRequest.propertyId, organizationId: organization.id, deletedAt: null },
        });
        if (!bed) throw new NotFoundError("Bed");
        if (bed.status !== BedStatus.VACANT) {
          throw new ConflictError(`Bed is ${bed.status}, must be VACANT to approve into it.`);
        }

        const existingTenancy = await tx.tenancy.findFirst({
          where: {
            organizationId: organization.id,
            userId: joinRequest.userId,
            deletedAt: null,
            status: { not: TenancyStatus.ARCHIVED },
          },
        });
        if (existingTenancy) {
          throw new ConflictError("This tenant already has an active or pending tenancy in this organization.");
        }

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `join-request:${requestId}` },
          async () => {
            await tx.bed.update({
              where: { id: bed.id },
              data: { status: BedStatus.RESERVED, version: { increment: 1 } },
            });

            const tenancy = await tx.tenancy.create({
              data: {
                organizationId: organization.id,
                propertyId: joinRequest.propertyId,
                bedId: bed.id,
                userId: joinRequest.userId,
                status: TenancyStatus.PENDING_ONBOARDING,
                rentAmount: body.rentAmount,
                depositAmount: body.depositAmount,
              },
            });
            await tx.tenancyEvent.create({
              data: { tenancyId: tenancy.id, type: "join_request_approved", actorId: member.userId },
            });

            const updatedRequest = await tx.joinRequest.update({
              where: { id: requestId },
              data: {
                status: JoinRequestStatus.APPROVED,
                tenancyId: tenancy.id,
                respondedBy: member.userId,
                responseNote: body.note,
              },
            });

            return { joinRequest: updatedRequest, tenancy };
          }
        );
      });

      return reply.status(200).send(ok(result));
    }
  );
}
