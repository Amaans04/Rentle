import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { BedStatus } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { NotFoundError, HttpError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";
import { assertManualBedTransition, requiresBlockedReason, requiresReservedUntil } from "../services/bed-status.js";

const createRoomSchema = z.object({
  floorId: z.string().min(1),
  roomNumber: z.string().min(1),
  roomType: z.string().default("single"),
  sharingCapacity: z.number().int().min(1).default(1),
  rentAmount: z.number().nonnegative(),
  mrpAmount: z.number().nonnegative(),
  amenities: z.array(z.string()).default([]),
});
const updateRoomSchema = createRoomSchema.partial().omit({ floorId: true });

const createBedSchema = z.object({
  bedLabel: z.string().min(1),
  rentAmount: z.number().nonnegative().optional(),
});
const updateBedSchema = z.object({
  bedLabel: z.string().min(1).optional(),
  rentAmount: z.number().nonnegative().nullable().optional(),
});

const statusUpdateSchema = z.object({
  status: z.nativeEnum(BedStatus),
  reservedUntil: z.coerce.date().optional(),
  blockedReason: z.string().optional(),
});

export async function roomBedRoutes(fastify: FastifyInstance): Promise<void> {
  // --- Rooms — flattened under propertyId, optional ?floorId= filter, per plan §3 ---

  fastify.post(
    "/organizations/:orgId/properties/:propertyId/rooms",
    { preHandler: [authenticate, resolveOrg, requirePermission("room:write")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(createRoomSchema, request.body);
      const { organization, member } = request.orgContext!;

      const room = await withRequestOrgContext(request, async (tx) => {
        const property = await tx.property.findFirst({
          where: { id: propertyId, organizationId: organization.id, deletedAt: null },
        });
        if (!property) throw new NotFoundError("Property");

        const floor = await tx.floor.findFirst({
          where: { id: body.floorId, organizationId: organization.id, deletedAt: null },
          include: { building: true },
        });
        if (!floor || floor.building.propertyId !== propertyId) {
          throw new HttpError(422, "INVALID_FLOOR", "floorId does not belong to this property.");
        }

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "room" },
          () => tx.room.create({ data: { ...body, propertyId, organizationId: organization.id } })
        );
      });

      return reply.status(201).send(ok(room));
    }
  );

  fastify.get(
    "/organizations/:orgId/properties/:propertyId/rooms",
    { preHandler: [authenticate, resolveOrg, requirePermission("room:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { floorId } = parseOrThrow(z.object({ floorId: z.string().optional() }), request.query);
      const { organization } = request.orgContext!;

      const rooms = await withRequestOrgContext(request, (tx) =>
        tx.room.findMany({
          where: { propertyId, organizationId: organization.id, deletedAt: null, ...(floorId ? { floorId } : {}) },
          include: { beds: { where: { deletedAt: null } } },
          orderBy: { roomNumber: "asc" },
        })
      );
      return reply.status(200).send(ok(rooms));
    }
  );

  fastify.get(
    "/organizations/:orgId/rooms/:roomId",
    { preHandler: [authenticate, resolveOrg, requirePermission("room:read")] },
    async (request, reply) => {
      const { roomId } = parseOrThrow(z.object({ roomId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const room = await withRequestOrgContext(request, (tx) =>
        tx.room.findFirst({
          where: { id: roomId, organizationId: organization.id, deletedAt: null },
          include: { beds: { where: { deletedAt: null } } },
        })
      );
      if (!room) throw new NotFoundError("Room");

      return reply.status(200).send(ok(room));
    }
  );

  fastify.patch(
    "/organizations/:orgId/rooms/:roomId",
    { preHandler: [authenticate, resolveOrg, requirePermission("room:write")] },
    async (request, reply) => {
      const { roomId } = parseOrThrow(z.object({ roomId: z.string().min(1) }), request.params);
      const body = parseOrThrow(updateRoomSchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.room.findFirst({ where: { id: roomId, organizationId: organization.id, deletedAt: null } });
        if (!existing) throw new NotFoundError("Room");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `room:${roomId}` },
          () => tx.room.update({ where: { id: roomId }, data: { ...body, version: { increment: 1 } } })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.delete(
    "/organizations/:orgId/rooms/:roomId",
    { preHandler: [authenticate, resolveOrg, requirePermission("room:write")] },
    async (request, reply) => {
      const { roomId } = parseOrThrow(z.object({ roomId: z.string().min(1) }), request.params);
      const { organization, member } = request.orgContext!;

      await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.room.findFirst({ where: { id: roomId, organizationId: organization.id, deletedAt: null } });
        if (!existing) throw new NotFoundError("Room");

        const activeBed = await tx.bed.findFirst({
          where: { roomId, organizationId: organization.id, deletedAt: null, status: BedStatus.OCCUPIED },
        });
        if (activeBed) {
          throw new HttpError(409, "CONFLICT", "Cannot delete a room with an occupied bed.");
        }

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "DELETE", resource: `room:${roomId}` },
          () => tx.room.update({ where: { id: roomId }, data: { deletedAt: new Date() } })
        );
      });

      return reply.status(204).send();
    }
  );

  // --- Beds — flattened under propertyId, optional ?roomId= filter, per plan §3 ---

  fastify.post(
    "/organizations/:orgId/rooms/:roomId/beds",
    { preHandler: [authenticate, resolveOrg, requirePermission("bed:write")] },
    async (request, reply) => {
      const { roomId } = parseOrThrow(z.object({ roomId: z.string().min(1) }), request.params);
      const body = parseOrThrow(createBedSchema, request.body);
      const { organization, member } = request.orgContext!;

      const bed = await withRequestOrgContext(request, async (tx) => {
        const room = await tx.room.findFirst({ where: { id: roomId, organizationId: organization.id, deletedAt: null } });
        if (!room) throw new NotFoundError("Room");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "bed" },
          () =>
            tx.bed.create({
              data: { ...body, roomId, propertyId: room.propertyId, organizationId: organization.id },
            })
        );
      });

      return reply.status(201).send(ok(bed));
    }
  );

  fastify.get(
    "/organizations/:orgId/properties/:propertyId/beds",
    { preHandler: [authenticate, resolveOrg, requirePermission("bed:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { roomId, status } = parseOrThrow(
        z.object({ roomId: z.string().optional(), status: z.nativeEnum(BedStatus).optional() }),
        request.query
      );
      const { organization } = request.orgContext!;

      const beds = await withRequestOrgContext(request, (tx) =>
        tx.bed.findMany({
          where: {
            propertyId,
            organizationId: organization.id,
            deletedAt: null,
            ...(roomId ? { roomId } : {}),
            ...(status ? { status } : {}),
          },
          orderBy: { bedLabel: "asc" },
        })
      );
      return reply.status(200).send(ok(beds));
    }
  );

  fastify.get(
    "/organizations/:orgId/beds/:bedId",
    { preHandler: [authenticate, resolveOrg, requirePermission("bed:read")] },
    async (request, reply) => {
      const { bedId } = parseOrThrow(z.object({ bedId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const bed = await withRequestOrgContext(request, (tx) =>
        tx.bed.findFirst({ where: { id: bedId, organizationId: organization.id, deletedAt: null } })
      );
      if (!bed) throw new NotFoundError("Bed");

      return reply.status(200).send(ok(bed));
    }
  );

  fastify.patch(
    "/organizations/:orgId/beds/:bedId",
    { preHandler: [authenticate, resolveOrg, requirePermission("bed:write")] },
    async (request, reply) => {
      const { bedId } = parseOrThrow(z.object({ bedId: z.string().min(1) }), request.params);
      const body = parseOrThrow(updateBedSchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.bed.findFirst({ where: { id: bedId, organizationId: organization.id, deletedAt: null } });
        if (!existing) throw new NotFoundError("Bed");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `bed:${bedId}` },
          () => tx.bed.update({ where: { id: bedId }, data: { ...body, version: { increment: 1 } } })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  // Explicit state-transition endpoint, per plan §3 — enforces the bed-status
  // machine (e.g. OCCUPIED unreachable manually) rather than a generic PATCH.
  fastify.patch(
    "/organizations/:orgId/beds/:bedId/status",
    { preHandler: [authenticate, resolveOrg, requirePermission("bed:write")] },
    async (request, reply) => {
      const { bedId } = parseOrThrow(z.object({ bedId: z.string().min(1) }), request.params);
      const body = parseOrThrow(statusUpdateSchema, request.body);
      const { organization, member } = request.orgContext!;

      if (requiresReservedUntil(body.status) && !body.reservedUntil) {
        throw new HttpError(422, "VALIDATION_ERROR", "reservedUntil is required when setting status to RESERVED.");
      }
      if (requiresBlockedReason(body.status) && !body.blockedReason) {
        throw new HttpError(422, "VALIDATION_ERROR", "blockedReason is required when setting status to BLOCKED.");
      }

      const updated = await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.bed.findFirst({ where: { id: bedId, organizationId: organization.id, deletedAt: null } });
        if (!existing) throw new NotFoundError("Bed");

        assertManualBedTransition(existing.status, body.status);

        return withAudit(
          tx,
          {
            organizationId: organization.id,
            userId: member.userId,
            action: "UPDATE",
            resource: `bed:${bedId}`,
            metadata: { statusTransition: { from: existing.status, to: body.status } },
          },
          () =>
            tx.bed.update({
              where: { id: bedId },
              data: {
                status: body.status,
                reservedUntil: body.status === BedStatus.RESERVED ? body.reservedUntil : null,
                blockedReason: body.status === BedStatus.BLOCKED ? body.blockedReason : null,
                version: { increment: 1 },
              },
            })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.delete(
    "/organizations/:orgId/beds/:bedId",
    { preHandler: [authenticate, resolveOrg, requirePermission("bed:write")] },
    async (request, reply) => {
      const { bedId } = parseOrThrow(z.object({ bedId: z.string().min(1) }), request.params);
      const { organization, member } = request.orgContext!;

      await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.bed.findFirst({ where: { id: bedId, organizationId: organization.id, deletedAt: null } });
        if (!existing) throw new NotFoundError("Bed");
        if (existing.status === BedStatus.OCCUPIED) {
          throw new HttpError(409, "CONFLICT", "Cannot delete an occupied bed.");
        }

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "DELETE", resource: `bed:${bedId}` },
          () => tx.bed.update({ where: { id: bedId }, data: { deletedAt: new Date() } })
        );
      });

      return reply.status(204).send();
    }
  );
}
