import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { ok } from "../lib/api-response.js";
import { NotFoundError } from "../lib/http-errors.js";
import { parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";

const nameSchema = z.object({ name: z.string().min(1), sortOrder: z.number().int().optional() });
const floorSchema = z.object({ name: z.string().min(1), level: z.number().int().default(0) });

/**
 * Buildings/Floors are lightweight structural metadata under a Property —
 * reuse property:read/property:write rather than introducing dedicated
 * permissions for what's essentially part of the property hierarchy.
 */
export async function buildingFloorRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post(
    "/organizations/:orgId/properties/:propertyId/buildings",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const body = parseOrThrow(nameSchema, request.body);
      const { organization, member } = request.orgContext!;

      const building = await withRequestOrgContext(request, async (tx) => {
        const property = await tx.property.findFirst({
          where: { id: propertyId, organizationId: organization.id, deletedAt: null },
        });
        if (!property) throw new NotFoundError("Property");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "building" },
          () =>
            tx.building.create({
              data: { ...body, propertyId, organizationId: organization.id },
            })
        );
      });

      return reply.status(201).send(ok(building));
    }
  );

  fastify.get(
    "/organizations/:orgId/properties/:propertyId/buildings",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(z.object({ propertyId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const buildings = await withRequestOrgContext(request, (tx) =>
        tx.building.findMany({
          where: { propertyId, organizationId: organization.id, deletedAt: null },
          orderBy: { sortOrder: "asc" },
        })
      );
      return reply.status(200).send(ok(buildings));
    }
  );

  fastify.patch(
    "/organizations/:orgId/buildings/:buildingId",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { buildingId } = parseOrThrow(z.object({ buildingId: z.string().min(1) }), request.params);
      const body = parseOrThrow(nameSchema.partial(), request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.building.findFirst({
          where: { id: buildingId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Building");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `building:${buildingId}` },
          () => tx.building.update({ where: { id: buildingId }, data: body })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.delete(
    "/organizations/:orgId/buildings/:buildingId",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { buildingId } = parseOrThrow(z.object({ buildingId: z.string().min(1) }), request.params);
      const { organization, member } = request.orgContext!;

      await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.building.findFirst({
          where: { id: buildingId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Building");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "DELETE", resource: `building:${buildingId}` },
          () => tx.building.update({ where: { id: buildingId }, data: { deletedAt: new Date() } })
        );
      });

      return reply.status(204).send();
    }
  );

  fastify.post(
    "/organizations/:orgId/buildings/:buildingId/floors",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { buildingId } = parseOrThrow(z.object({ buildingId: z.string().min(1) }), request.params);
      const body = parseOrThrow(floorSchema, request.body);
      const { organization, member } = request.orgContext!;

      const floor = await withRequestOrgContext(request, async (tx) => {
        const building = await tx.building.findFirst({
          where: { id: buildingId, organizationId: organization.id, deletedAt: null },
        });
        if (!building) throw new NotFoundError("Building");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "floor" },
          () => tx.floor.create({ data: { ...body, buildingId, organizationId: organization.id } })
        );
      });

      return reply.status(201).send(ok(floor));
    }
  );

  fastify.get(
    "/organizations/:orgId/buildings/:buildingId/floors",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:read")] },
    async (request, reply) => {
      const { buildingId } = parseOrThrow(z.object({ buildingId: z.string().min(1) }), request.params);
      const { organization } = request.orgContext!;

      const floors = await withRequestOrgContext(request, (tx) =>
        tx.floor.findMany({
          where: { buildingId, organizationId: organization.id, deletedAt: null },
          orderBy: { level: "asc" },
        })
      );
      return reply.status(200).send(ok(floors));
    }
  );

  fastify.patch(
    "/organizations/:orgId/floors/:floorId",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { floorId } = parseOrThrow(z.object({ floorId: z.string().min(1) }), request.params);
      const body = parseOrThrow(floorSchema.partial(), request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.floor.findFirst({
          where: { id: floorId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Floor");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `floor:${floorId}` },
          () => tx.floor.update({ where: { id: floorId }, data: body })
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.delete(
    "/organizations/:orgId/floors/:floorId",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { floorId } = parseOrThrow(z.object({ floorId: z.string().min(1) }), request.params);
      const { organization, member } = request.orgContext!;

      await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.floor.findFirst({
          where: { id: floorId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Floor");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "DELETE", resource: `floor:${floorId}` },
          () => tx.floor.update({ where: { id: floorId }, data: { deletedAt: new Date() } })
        );
      });

      return reply.status(204).send();
    }
  );
}
