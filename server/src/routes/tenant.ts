import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { BedStatus, ComplaintPriority, TenancyStatus, type Prisma } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { HttpError, NotFoundError } from "../lib/http-errors.js";
import { orgIdParamSchema, parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveTenantContext, withRequestTenantContext } from "../auth/pipeline.js";
import { withOrgContext } from "../auth/db-context.js";
import { withAudit } from "../lib/with-audit.js";
import { verifyOnboardingToken } from "../lib/onboarding-token.js";
import { visibleNoticeWhere } from "../services/notice-visibility.js";

const createComplaintSchema = z.object({
  title: z.string().min(1),
  description: z.string().min(1),
  category: z.string().min(1),
  priority: z.nativeEnum(ComplaintPriority).default(ComplaintPriority.MEDIUM),
  photos: z.array(z.string()).default([]),
});
const commentSchema = z.object({ content: z.string().min(1) });

const acceptSchema = z.object({
  token: z.string().min(1),
  emergencyContact: z.record(z.string(), z.unknown()).optional(),
  parentDetails: z.record(z.string(), z.unknown()).optional(),
});

const documentUploadRequestSchema = z.object({ fileName: z.string().min(1), type: z.string().min(1) });
const documentConfirmSchema = z.object({
  storageKey: z.string().min(1),
  type: z.string().min(1),
  fileName: z.string().min(1),
  mimeType: z.string().min(1),
  sizeBytes: z.number().int().positive(),
});

export async function tenantSelfRoutes(fastify: FastifyInstance): Promise<void> {
  /**
   * The one tenant-facing endpoint that runs BEFORE a Tenancy row exists,
   * so it can't use resolveTenantContext (which requires one to already be
   * there). Trust here comes entirely from the signed token's HMAC
   * signature — the same role resolveOrg's membership lookup plays
   * elsewhere — never from any other client-supplied field. orgId in the
   * URL is cross-checked against the token's own orgId as defense in depth,
   * but the token is what's actually trusted.
   */
  fastify.post(
    "/organizations/:orgId/tenant/onboarding/accept",
    { preHandler: [authenticate] },
    async (request, reply) => {
      const { orgId } = parseOrThrow(orgIdParamSchema, request.params);
      const body = parseOrThrow(acceptSchema, request.body);

      const payload = verifyOnboardingToken(body.token);
      if (!payload) {
        throw new HttpError(400, "INVALID_TOKEN", "This invite link is invalid or has expired.");
      }
      if (payload.organizationId !== orgId) {
        throw new HttpError(400, "INVALID_TOKEN", "This invite link does not match this organization.");
      }

      const tenancy = await withOrgContext(payload.organizationId, async (tx) => {
        const bed = await tx.bed.findFirst({
          where: { id: payload.bedId, organizationId: payload.organizationId, deletedAt: null },
        });
        if (!bed || bed.status !== BedStatus.RESERVED) {
          throw new HttpError(409, "CONFLICT", "This bed is no longer reserved for onboarding.");
        }

        // A user can only have one non-archived tenancy per org at a time —
        // this is also what makes resolveTenantContext's lookup unambiguous.
        const existing = await tx.tenancy.findFirst({
          where: {
            organizationId: payload.organizationId,
            userId: request.authUser!.id,
            deletedAt: null,
            status: { not: TenancyStatus.ARCHIVED },
          },
        });
        if (existing) {
          throw new HttpError(409, "CONFLICT", "You already have an active or pending tenancy in this organization.");
        }

        return withAudit(
          tx,
          {
            organizationId: payload.organizationId,
            userId: request.authUser!.id,
            action: "CREATE",
            resource: "tenancy",
          },
          async () => {
            const created = await tx.tenancy.create({
              data: {
                organizationId: payload.organizationId,
                propertyId: payload.propertyId,
                bedId: payload.bedId,
                userId: request.authUser!.id,
                status: TenancyStatus.PENDING_ONBOARDING,
                rentAmount: payload.rentAmount,
                depositAmount: payload.depositAmount,
                emergencyContact: body.emergencyContact as Prisma.InputJsonValue | undefined,
                parentDetails: body.parentDetails as Prisma.InputJsonValue | undefined,
              },
            });
            await tx.tenancyEvent.create({
              data: { tenancyId: created.id, type: "onboarding_accepted", actorId: request.authUser!.id },
            });
            return created;
          }
        );
      });

      return reply.status(201).send(ok(tenancy));
    }
  );

  fastify.get(
    "/organizations/:orgId/tenant/me",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const { tenancy } = request.tenantContext!;
      const full = await withRequestTenantContext(request, (tx) =>
        tx.tenancy.findUnique({
          where: { id: tenancy.id },
          include: { bed: { include: { room: true } }, events: { orderBy: { createdAt: "desc" } } },
        })
      );
      return reply.status(200).send(ok(full));
    }
  );

  fastify.post(
    "/organizations/:orgId/tenant/documents",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const body = parseOrThrow(documentUploadRequestSchema, request.body);
      const { organization, tenancy } = request.tenantContext!;

      const { supabaseStorage } = await import("../lib/supabase-storage.js");
      const path = `${organization.id}/${tenancy.id}/${Date.now()}-${body.fileName}`;
      const { signedUrl, storageKey } = await supabaseStorage.createSignedUploadUrl({
        bucket: "tenant-documents",
        path,
      });

      return reply.status(200).send(ok({ signedUrl, storageKey }));
    }
  );

  fastify.post(
    "/organizations/:orgId/tenant/documents/confirm",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const body = parseOrThrow(documentConfirmSchema, request.body);
      const { organization, tenancy } = request.tenantContext!;

      const document = await withRequestTenantContext(request, (tx) =>
        withAudit(
          tx,
          { organizationId: organization.id, userId: request.authUser!.id, action: "CREATE", resource: "tenant-document" },
          () => tx.tenantDocument.create({ data: { ...body, tenancyId: tenancy.id } })
        )
      );

      return reply.status(201).send(ok(document));
    }
  );

  fastify.get(
    "/organizations/:orgId/tenant/documents",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const { tenancy } = request.tenantContext!;
      const documents = await withRequestTenantContext(request, (tx) =>
        tx.tenantDocument.findMany({ where: { tenancyId: tenancy.id }, orderBy: { createdAt: "desc" } })
      );
      return reply.status(200).send(ok(documents));
    }
  );

  // --- Complaints ---

  fastify.post(
    "/organizations/:orgId/tenant/complaints",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const body = parseOrThrow(createComplaintSchema, request.body);
      const { organization, tenancy } = request.tenantContext!;

      const complaint = await withRequestTenantContext(request, (tx) =>
        withAudit(
          tx,
          { organizationId: organization.id, userId: request.authUser!.id, action: "CREATE", resource: "complaint" },
          () =>
            tx.complaint.create({
              data: {
                organizationId: organization.id,
                propertyId: tenancy.propertyId,
                reporterId: request.authUser!.id,
                title: body.title,
                description: body.description,
                category: body.category,
                priority: body.priority,
                photos: body.photos,
              },
            })
        )
      );

      return reply.status(201).send(ok(complaint));
    }
  );

  fastify.get(
    "/organizations/:orgId/tenant/complaints",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const complaints = await withRequestTenantContext(request, (tx) =>
        tx.complaint.findMany({ where: { reporterId: request.authUser!.id }, orderBy: { createdAt: "desc" } })
      );
      return reply.status(200).send(ok(complaints));
    }
  );

  fastify.get(
    "/organizations/:orgId/tenant/complaints/:complaintId",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const { complaintId } = parseOrThrow(z.object({ complaintId: z.string().min(1) }), request.params);

      // Ownership re-derivation — reporterId must match the caller, never
      // trust the complaintId path param alone.
      const complaint = await withRequestTenantContext(request, (tx) =>
        tx.complaint.findFirst({
          where: { id: complaintId, reporterId: request.authUser!.id },
          include: { comments: { orderBy: { createdAt: "asc" } } },
        })
      );
      if (!complaint) throw new NotFoundError("Complaint");

      return reply.status(200).send(ok(complaint));
    }
  );

  fastify.post(
    "/organizations/:orgId/tenant/complaints/:complaintId/comments",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const { complaintId } = parseOrThrow(z.object({ complaintId: z.string().min(1) }), request.params);
      const body = parseOrThrow(commentSchema, request.body);
      const { organization } = request.tenantContext!;

      const comment = await withRequestTenantContext(request, async (tx) => {
        const complaint = await tx.complaint.findFirst({ where: { id: complaintId, reporterId: request.authUser!.id } });
        if (!complaint) throw new NotFoundError("Complaint");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: request.authUser!.id, action: "CREATE", resource: "complaint-comment" },
          () => tx.complaintComment.create({ data: { complaintId, authorId: request.authUser!.id, content: body.content } })
        );
      });

      return reply.status(201).send(ok(comment));
    }
  );

  // --- Notices — filtered by audience targeting (ALL_TENANTS/PROPERTY always
  // visible; FLOOR/ROOM only to tenants actually on that floor/in that room) ---

  fastify.get(
    "/organizations/:orgId/tenant/notices",
    { preHandler: [authenticate, resolveTenantContext] },
    async (request, reply) => {
      const { organization, tenancy } = request.tenantContext!;

      const notices = await withRequestTenantContext(request, async (tx) => {
        const bed = await tx.bed.findUniqueOrThrow({ where: { id: tenancy.bedId }, include: { room: true } });
        return tx.notice.findMany({
          where: visibleNoticeWhere({
            organizationId: organization.id,
            propertyId: tenancy.propertyId,
            floorId: bed.room.floorId,
            roomId: bed.roomId,
            now: new Date(),
          }),
          orderBy: { createdAt: "desc" },
        });
      });

      return reply.status(200).send(ok(notices));
    }
  );
}
