import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { NoticeAudience, type Prisma } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { NotFoundError, HttpError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";

const createNoticeSchema = z.object({
  title: z.string().min(1),
  body: z.string().min(1),
  audience: z.nativeEnum(NoticeAudience).default(NoticeAudience.ALL_TENANTS),
  floorId: z.string().optional(), // required when audience === FLOOR
  roomId: z.string().optional(), // required when audience === ROOM
  attachments: z.array(z.string()).default([]),
  publishAt: z.coerce.date().optional(),
  expiresAt: z.coerce.date().optional(),
});

const updateNoticeSchema = createNoticeSchema.partial();

function buildAudienceFilter(audience: NoticeAudience, floorId?: string, roomId?: string): Prisma.InputJsonValue | undefined {
  if (audience === NoticeAudience.FLOOR) {
    if (!floorId) throw new HttpError(422, "VALIDATION_ERROR", "floorId is required when audience is FLOOR.");
    return { floorId };
  }
  if (audience === NoticeAudience.ROOM) {
    if (!roomId) throw new HttpError(422, "VALIDATION_ERROR", "roomId is required when audience is ROOM.");
    return { roomId };
  }
  return undefined;
}

export async function noticeRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post(
    "/organizations/:orgId/properties/:propertyId/notices",
    { preHandler: [authenticate, resolveOrg, requirePermission("notice:write")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(createNoticeSchema, request.body);
      const { organization, member } = request.orgContext!;

      const audienceFilter = buildAudienceFilter(body.audience, body.floorId, body.roomId);

      const notice = await withRequestOrgContext(request, async (tx) => {
        const property = await tx.property.findFirst({ where: { id: propertyId, organizationId: organization.id, deletedAt: null } });
        if (!property) throw new NotFoundError("Property");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "notice" },
          () =>
            tx.notice.create({
              data: {
                organizationId: organization.id,
                propertyId,
                title: body.title,
                body: body.body,
                audience: body.audience,
                audienceFilter,
                attachments: body.attachments,
                publishAt: body.publishAt,
                expiresAt: body.expiresAt,
                publishedAt: !body.publishAt || body.publishAt <= new Date() ? new Date() : null,
              },
            })
        );
      });

      return reply.status(201).send(ok(notice));
    }
  );

  fastify.get(
    "/organizations/:orgId/properties/:propertyId/notices",
    { preHandler: [authenticate, resolveOrg, requirePermission("notice:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const notices = await withRequestOrgContext(request, (tx) =>
        tx.notice.findMany({ where: { propertyId, organizationId: organization.id }, orderBy: { createdAt: "desc" } })
      );
      return reply.status(200).send(ok(notices));
    }
  );

  fastify.patch(
    "/organizations/:orgId/notices/:noticeId",
    { preHandler: [authenticate, resolveOrg, requirePermission("notice:write")] },
    async (request, reply) => {
      const { noticeId } = parseOrThrow(z.object({ noticeId: z.string().min(1) }), request.params);
      const body = parseOrThrow(updateNoticeSchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.notice.findFirst({ where: { id: noticeId, organizationId: organization.id } });
        if (!existing) throw new NotFoundError("Notice");

        const audience = body.audience ?? existing.audience;
        const audienceFilter =
          body.audience || body.floorId || body.roomId
            ? buildAudienceFilter(audience, body.floorId, body.roomId)
            : (existing.audienceFilter as Prisma.InputJsonValue | undefined);

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `notice:${noticeId}` },
          () =>
            tx.notice.update({
              where: { id: noticeId },
              data: {
                title: body.title,
                body: body.body,
                audience,
                audienceFilter,
                attachments: body.attachments,
                publishAt: body.publishAt,
                expiresAt: body.expiresAt,
              },
            })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.delete(
    "/organizations/:orgId/notices/:noticeId",
    { preHandler: [authenticate, resolveOrg, requirePermission("notice:write")] },
    async (request, reply) => {
      const { noticeId } = parseOrThrow(z.object({ noticeId: z.string().min(1) }), request.params);
      const { organization, member } = request.orgContext!;

      await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.notice.findFirst({ where: { id: noticeId, organizationId: organization.id } });
        if (!existing) throw new NotFoundError("Notice");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "DELETE", resource: `notice:${noticeId}` },
          () => tx.notice.delete({ where: { id: noticeId } })
        );
      });

      return reply.status(204).send();
    }
  );
}
