import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { ComplaintPriority, ComplaintStatus } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { HttpError, NotFoundError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";
import { assertComplaintTransition } from "../services/complaint-status.js";

const assignSchema = z.object({ assigneeId: z.string().min(1).nullable() });
const statusSchema = z.object({ status: z.nativeEnum(ComplaintStatus) });
const commentSchema = z.object({ content: z.string().min(1) });

export async function complaintRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.get(
    "/organizations/:orgId/properties/:propertyId/complaints",
    { preHandler: [authenticate, resolveOrg, requirePermission("complaint:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { status, priority } = parseOrThrow(
        z.object({ status: z.nativeEnum(ComplaintStatus).optional(), priority: z.nativeEnum(ComplaintPriority).optional() }),
        request.query
      );
      const { organization } = request.orgContext!;

      const complaints = await withRequestOrgContext(request, (tx) =>
        tx.complaint.findMany({
          where: { propertyId, organizationId: organization.id, ...(status ? { status } : {}), ...(priority ? { priority } : {}) },
          include: { reporter: { select: { id: true, name: true, phone: true } }, assignee: { select: { id: true, name: true } } },
          orderBy: { createdAt: "desc" },
        })
      );
      return reply.status(200).send(ok(complaints));
    }
  );

  fastify.get(
    "/organizations/:orgId/complaints/:complaintId",
    { preHandler: [authenticate, resolveOrg, requirePermission("complaint:read")] },
    async (request, reply) => {
      const { complaintId } = parseOrThrow(z.object({ complaintId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const complaint = await withRequestOrgContext(request, (tx) =>
        tx.complaint.findFirst({
          where: { id: complaintId, organizationId: organization.id },
          include: {
            reporter: { select: { id: true, name: true, phone: true } },
            assignee: { select: { id: true, name: true } },
            comments: { orderBy: { createdAt: "asc" } },
          },
        })
      );
      if (!complaint) throw new NotFoundError("Complaint");

      return reply.status(200).send(ok(complaint));
    }
  );

  fastify.patch(
    "/organizations/:orgId/complaints/:complaintId/assign",
    { preHandler: [authenticate, resolveOrg, requirePermission("complaint:write")] },
    async (request, reply) => {
      const { complaintId } = parseOrThrow(z.object({ complaintId: z.string().min(1) }), request.params);
      const body = parseOrThrow(assignSchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const complaint = await tx.complaint.findFirst({ where: { id: complaintId, organizationId: organization.id } });
        if (!complaint) throw new NotFoundError("Complaint");

        if (body.assigneeId) {
          const assignee = await tx.organizationMember.findFirst({
            where: { userId: body.assigneeId, organizationId: organization.id, isActive: true, deletedAt: null },
          });
          if (!assignee) throw new HttpError(422, "INVALID_ASSIGNEE", "assigneeId is not an active member of this organization.");
        }

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `complaint:${complaintId}` },
          () => tx.complaint.update({ where: { id: complaintId }, data: { assigneeId: body.assigneeId, version: { increment: 1 } } })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.patch(
    "/organizations/:orgId/complaints/:complaintId/status",
    { preHandler: [authenticate, resolveOrg, requirePermission("complaint:write")] },
    async (request, reply) => {
      const { complaintId } = parseOrThrow(z.object({ complaintId: z.string().min(1) }), request.params);
      const body = parseOrThrow(statusSchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const complaint = await tx.complaint.findFirst({ where: { id: complaintId, organizationId: organization.id } });
        if (!complaint) throw new NotFoundError("Complaint");
        assertComplaintTransition(complaint.status, body.status);

        return withAudit(
          tx,
          {
            organizationId: organization.id,
            userId: member.userId,
            action: "UPDATE",
            resource: `complaint:${complaintId}`,
            metadata: { statusTransition: { from: complaint.status, to: body.status } },
          },
          () =>
            tx.complaint.update({
              where: { id: complaintId },
              data: {
                status: body.status,
                resolvedAt: body.status === ComplaintStatus.RESOLVED ? new Date() : complaint.resolvedAt,
                version: { increment: 1 },
              },
            })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.post(
    "/organizations/:orgId/complaints/:complaintId/comments",
    { preHandler: [authenticate, resolveOrg, requirePermission("complaint:write")] },
    async (request, reply) => {
      const { complaintId } = parseOrThrow(z.object({ complaintId: z.string().min(1) }), request.params);
      const body = parseOrThrow(commentSchema, request.body);
      const { organization, member } = request.orgContext!;

      const comment = await withRequestOrgContext(request, async (tx) => {
        const complaint = await tx.complaint.findFirst({ where: { id: complaintId, organizationId: organization.id } });
        if (!complaint) throw new NotFoundError("Complaint");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "complaint-comment" },
          () => tx.complaintComment.create({ data: { complaintId, authorId: member.userId, content: body.content } })
        );
      });

      return reply.status(201).send(ok(comment));
    }
  );
}
