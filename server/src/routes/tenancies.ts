import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { BedStatus, TenancyStatus } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { NotFoundError, HttpError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";
import { signOnboardingToken } from "../lib/onboarding-token.js";
import { assertTenancyTransition } from "../services/tenancy-status.js";

const inviteSchema = z.object({
  bedId: z.string().min(1),
  rentAmount: z.number().nonnegative(),
  depositAmount: z.number().nonnegative().default(0),
  expiresInDays: z.number().int().min(1).max(30).default(7),
});

const documentConfirmSchema = z.object({
  storageKey: z.string().min(1),
  type: z.string().min(1),
  fileName: z.string().min(1),
  mimeType: z.string().min(1),
  sizeBytes: z.number().int().positive(),
});

const documentUploadRequestSchema = z.object({
  fileName: z.string().min(1),
  type: z.string().min(1),
});

const transferSchema = z.object({ newBedId: z.string().min(1) });
const moveOutSchema = z.object({ moveOutDate: z.coerce.date().optional() });

export async function tenancyRoutes(fastify: FastifyInstance): Promise<void> {
  // --- Invite: creates a signed token, no Tenancy row yet (see onboarding-token.ts) ---

  fastify.post(
    "/organizations/:orgId/properties/:propertyId/tenancies/invite",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:write")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(inviteSchema, request.body);
      const { organization, member } = request.orgContext!;

      const token = await withRequestOrgContext(request, async (tx) => {
        const bed = await tx.bed.findFirst({
          where: { id: body.bedId, propertyId, organizationId: organization.id, deletedAt: null },
        });
        if (!bed) throw new NotFoundError("Bed");
        if (bed.status !== BedStatus.VACANT) {
          throw new HttpError(409, "CONFLICT", `Bed is ${bed.status}, must be VACANT to invite a tenant.`);
        }

        const expiresAt = new Date(Date.now() + body.expiresInDays * 24 * 60 * 60 * 1000);

        return withAudit(
          tx,
          {
            organizationId: organization.id,
            userId: member.userId,
            action: "CREATE",
            resource: "tenancy-invite",
            metadata: { bedId: body.bedId, expiresAt: expiresAt.toISOString() },
          },
          async () => {
            // Reserve the bed for the pending invite — a direct Prisma
            // write, not through the guarded manual status endpoint (see
            // services/bed-status.ts): that endpoint's restrictions are
            // about staff manually fudging status, not about the tenancy
            // flow itself, which is the intended source of truth for
            // RESERVED/OCCUPIED transitions.
            await tx.bed.update({
              where: { id: bed.id },
              data: { status: BedStatus.RESERVED, reservedUntil: expiresAt, version: { increment: 1 } },
            });

            return signOnboardingToken({
              organizationId: organization.id,
              propertyId,
              bedId: bed.id,
              rentAmount: body.rentAmount,
              depositAmount: body.depositAmount,
              exp: Math.floor(expiresAt.getTime() / 1000),
            });
          }
        );
      });

      return reply.status(201).send(ok({ token, expiresInDays: body.expiresInDays }));
    }
  );

  // --- CRUD ---

  fastify.get(
    "/organizations/:orgId/properties/:propertyId/tenancies",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { status } = parseOrThrow(z.object({ status: z.nativeEnum(TenancyStatus).optional() }), request.query);
      const { organization } = request.orgContext!;

      const tenancies = await withRequestOrgContext(request, (tx) =>
        tx.tenancy.findMany({
          where: {
            propertyId,
            organizationId: organization.id,
            deletedAt: null,
            ...(status ? { status } : {}),
          },
          include: { user: { select: { id: true, name: true, email: true, phone: true } }, bed: true },
          orderBy: { createdAt: "desc" },
        })
      );
      return reply.status(200).send(ok(tenancies));
    }
  );

  fastify.get(
    "/organizations/:orgId/tenancies/:tenancyId",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:read")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const tenancy = await withRequestOrgContext(request, (tx) =>
        tx.tenancy.findFirst({
          where: { id: tenancyId, organizationId: organization.id, deletedAt: null },
          include: {
            user: { select: { id: true, name: true, email: true, phone: true } },
            bed: true,
            events: { orderBy: { createdAt: "desc" } },
            documents: true,
          },
        })
      );
      if (!tenancy) throw new NotFoundError("Tenancy");

      return reply.status(200).send(ok(tenancy));
    }
  );

  // --- Lifecycle transitions — each writes a TenancyEvent + keeps Bed.status in sync ---

  fastify.patch(
    "/organizations/:orgId/tenancies/:tenancyId/activate",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:write")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const tenancy = await tx.tenancy.findFirst({
          where: { id: tenancyId, organizationId: organization.id, deletedAt: null },
        });
        if (!tenancy) throw new NotFoundError("Tenancy");
        assertTenancyTransition(tenancy.status, TenancyStatus.ACTIVE);

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `tenancy:${tenancyId}` },
          async () => {
            await tx.bed.update({
              where: { id: tenancy.bedId },
              data: { status: BedStatus.OCCUPIED, reservedUntil: null, version: { increment: 1 } },
            });
            await tx.tenancyEvent.create({
              data: { tenancyId, type: "activated", actorId: member.userId },
            });
            return tx.tenancy.update({
              where: { id: tenancyId },
              data: { status: TenancyStatus.ACTIVE, moveInDate: new Date(), version: { increment: 1 } },
            });
          }
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.patch(
    "/organizations/:orgId/tenancies/:tenancyId/notice",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:write")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const tenancy = await tx.tenancy.findFirst({
          where: { id: tenancyId, organizationId: organization.id, deletedAt: null },
        });
        if (!tenancy) throw new NotFoundError("Tenancy");
        assertTenancyTransition(tenancy.status, TenancyStatus.NOTICE_GIVEN);

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `tenancy:${tenancyId}` },
          async () => {
            await tx.tenancyEvent.create({ data: { tenancyId, type: "notice_given", actorId: member.userId } });
            return tx.tenancy.update({
              where: { id: tenancyId },
              data: { status: TenancyStatus.NOTICE_GIVEN, noticeDate: new Date(), version: { increment: 1 } },
            });
          }
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.patch(
    "/organizations/:orgId/tenancies/:tenancyId/move-out",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:write")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(moveOutSchema, request.body ?? {});
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const tenancy = await tx.tenancy.findFirst({
          where: { id: tenancyId, organizationId: organization.id, deletedAt: null },
        });
        if (!tenancy) throw new NotFoundError("Tenancy");
        assertTenancyTransition(tenancy.status, TenancyStatus.ARCHIVED);

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `tenancy:${tenancyId}` },
          async () => {
            await tx.bed.update({
              where: { id: tenancy.bedId },
              data: { status: BedStatus.VACANT, version: { increment: 1 } },
            });
            await tx.tenancyEvent.create({ data: { tenancyId, type: "moved_out", actorId: member.userId } });
            return tx.tenancy.update({
              where: { id: tenancyId },
              data: { status: TenancyStatus.ARCHIVED, moveOutDate: body.moveOutDate ?? new Date(), version: { increment: 1 } },
            });
          }
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.patch(
    "/organizations/:orgId/tenancies/:tenancyId/transfer",
    { preHandler: [authenticate, resolveOrg, requirePermission("tenancy:write")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(transferSchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const tenancy = await tx.tenancy.findFirst({
          where: { id: tenancyId, organizationId: organization.id, deletedAt: null },
        });
        if (!tenancy) throw new NotFoundError("Tenancy");
        if (tenancy.status !== TenancyStatus.ACTIVE) {
          throw new HttpError(422, "INVALID_TRANSITION", "Only an ACTIVE tenancy can be transferred.");
        }

        const newBed = await tx.bed.findFirst({
          where: { id: body.newBedId, organizationId: organization.id, deletedAt: null },
        });
        if (!newBed) throw new NotFoundError("Bed");
        if (newBed.status !== BedStatus.VACANT) {
          throw new HttpError(409, "CONFLICT", `Target bed is ${newBed.status}, must be VACANT.`);
        }

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `tenancy:${tenancyId}` },
          async () => {
            await tx.bed.update({
              where: { id: tenancy.bedId },
              data: { status: BedStatus.VACANT, version: { increment: 1 } },
            });
            await tx.bed.update({
              where: { id: newBed.id },
              data: { status: BedStatus.OCCUPIED, version: { increment: 1 } },
            });
            await tx.tenancyEvent.create({
              data: { tenancyId, type: "transferred", actorId: member.userId, metadata: { fromBedId: tenancy.bedId, toBedId: newBed.id } },
            });
            return tx.tenancy.update({
              where: { id: tenancyId },
              data: { bedId: newBed.id, propertyId: newBed.propertyId, version: { increment: 1 } },
            });
          }
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  // --- Documents: signed upload URL, then a confirm call writes the row ---

  fastify.post(
    "/organizations/:orgId/tenancies/:tenancyId/documents",
    { preHandler: [authenticate, resolveOrg, requirePermission("document:write")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(documentUploadRequestSchema, request.body);
      const { organization } = request.orgContext!;

      const tenancy = await withRequestOrgContext(request, (tx) =>
        tx.tenancy.findFirst({ where: { id: tenancyId, organizationId: organization.id, deletedAt: null } })
      );
      if (!tenancy) throw new NotFoundError("Tenancy");

      const { supabaseStorage } = await import("../lib/supabase-storage.js");
      const path = `${organization.id}/${tenancyId}/${Date.now()}-${body.fileName}`;
      const { signedUrl, storageKey } = await supabaseStorage.createSignedUploadUrl({
        bucket: "tenant-documents",
        path,
      });

      return reply.status(200).send(ok({ signedUrl, storageKey }));
    }
  );

  fastify.post(
    "/organizations/:orgId/tenancies/:tenancyId/documents/confirm",
    { preHandler: [authenticate, resolveOrg, requirePermission("document:write")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(documentConfirmSchema, request.body);
      const { organization, member } = request.orgContext!;

      const document = await withRequestOrgContext(request, async (tx) => {
        const tenancy = await tx.tenancy.findFirst({
          where: { id: tenancyId, organizationId: organization.id, deletedAt: null },
        });
        if (!tenancy) throw new NotFoundError("Tenancy");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "tenant-document" },
          () => tx.tenantDocument.create({ data: { ...body, tenancyId } })
        );
      });

      return reply.status(201).send(ok(document));
    }
  );

  fastify.get(
    "/organizations/:orgId/tenancies/:tenancyId/documents",
    { preHandler: [authenticate, resolveOrg, requirePermission("document:read")] },
    async (request, reply) => {
      const { tenancyId } = parseOrThrow(z.object({ tenancyId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const tenancy = await withRequestOrgContext(request, (tx) =>
        tx.tenancy.findFirst({ where: { id: tenancyId, organizationId: organization.id, deletedAt: null } })
      );
      if (!tenancy) throw new NotFoundError("Tenancy");

      const documents = await withRequestOrgContext(request, (tx) =>
        tx.tenantDocument.findMany({ where: { tenancyId }, orderBy: { createdAt: "desc" } })
      );
      return reply.status(200).send(ok(documents));
    }
  );
}
