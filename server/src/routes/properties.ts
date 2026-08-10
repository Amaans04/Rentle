import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { PropertyType } from "@prisma/client";
import { ok } from "../lib/api-response.js";
import { NotFoundError, HttpError } from "../lib/http-errors.js";
import { addressSchema, parseOrThrow } from "../lib/validation.js";
import { authenticate, resolveOrg, requirePermission, withRequestOrgContext } from "../auth/pipeline.js";
import { withAudit } from "../lib/with-audit.js";
import { syncPropertyListing } from "../services/property-listing.js";

const createPropertySchema = z.object({
  name: z.string().min(1),
  slug: z
    .string()
    .min(1)
    .regex(/^[a-z0-9-]+$/, "slug must be lowercase letters, numbers, and hyphens only"),
  type: z.nativeEnum(PropertyType).default(PropertyType.PG),
  address: addressSchema,
  phone: z.string().optional(),
  email: z.string().email().optional(),
  amenities: z.array(z.string()).default([]),
  rentDueDay: z.number().int().min(1).max(28).default(5),
  gracePeriodDays: z.number().int().min(0).default(3),
  lateFinePercent: z.number().min(0).max(100).optional(),
  discoverable: z.boolean().default(true),
});

const updatePropertySchema = createPropertySchema.partial();

const propertyIdParamSchema = z.object({ orgId: z.string().min(1), propertyId: z.string().min(1) });

export async function propertyRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.post(
    "/organizations/:orgId/properties",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { organization, member } = request.orgContext!;

      // Property-scoped members (propertyIds non-empty) can act within their
      // assigned properties, but creating a NEW property is an org-level
      // action requirePermission's per-request :propertyId check can't catch
      // (there's no propertyId yet) — enforced explicitly here instead.
      if (member.propertyIds.length > 0) {
        throw new HttpError(403, "FORBIDDEN", "Only unrestricted members can create new properties.");
      }

      const body = parseOrThrow(createPropertySchema, request.body);

      const property = await withRequestOrgContext(request, (tx) =>
        withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "CREATE", resource: "property" },
          async () => {
            const created = await tx.property.create({
              data: { ...body, organizationId: organization.id },
            });
            await syncPropertyListing(tx, created);
            return created;
          }
        )
      );

      return reply.status(201).send(ok(property));
    }
  );

  fastify.get(
    "/organizations/:orgId/properties",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:read")] },
    async (request, reply) => {
      const { organization, member } = request.orgContext!;
      const properties = await withRequestOrgContext(request, (tx) =>
        tx.property.findMany({
          where: {
            organizationId: organization.id,
            deletedAt: null,
            ...(member.propertyIds.length > 0 ? { id: { in: member.propertyIds } } : {}),
          },
          orderBy: { createdAt: "asc" },
        })
      );
      return reply.status(200).send(ok(properties));
    }
  );

  fastify.get(
    "/organizations/:orgId/properties/:propertyId",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:read")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(propertyIdParamSchema, request.params);
      const { organization } = request.orgContext!;

      const property = await withRequestOrgContext(request, (tx) =>
        tx.property.findFirst({ where: { id: propertyId, organizationId: organization.id, deletedAt: null } })
      );
      if (!property) throw new NotFoundError("Property");

      return reply.status(200).send(ok(property));
    }
  );

  fastify.patch(
    "/organizations/:orgId/properties/:propertyId",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(propertyIdParamSchema, request.params);
      const body = parseOrThrow(updatePropertySchema, request.body);
      const { organization, member } = request.orgContext!;

      const updated = await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.property.findFirst({
          where: { id: propertyId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Property");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "UPDATE", resource: `property:${propertyId}` },
          async () => {
            const saved = await tx.property.update({
              where: { id: propertyId },
              data: { ...body, version: { increment: 1 } },
            });
            await syncPropertyListing(tx, saved);
            return saved;
          }
        );
      });

      return reply.status(200).send(ok(updated));
    }
  );

  fastify.delete(
    "/organizations/:orgId/properties/:propertyId",
    { preHandler: [authenticate, resolveOrg, requirePermission("property:write")] },
    async (request, reply) => {
      const { propertyId } = parseOrThrow(propertyIdParamSchema, request.params);
      const { organization, member } = request.orgContext!;

      await withRequestOrgContext(request, async (tx) => {
        const existing = await tx.property.findFirst({
          where: { id: propertyId, organizationId: organization.id, deletedAt: null },
        });
        if (!existing) throw new NotFoundError("Property");

        return withAudit(
          tx,
          { organizationId: organization.id, userId: member.userId, action: "DELETE", resource: `property:${propertyId}` },
          async () => {
            const saved = await tx.property.update({ where: { id: propertyId }, data: { deletedAt: new Date() } });
            await syncPropertyListing(tx, saved);
            return saved;
          }
        );
      });

      return reply.status(204).send();
    }
  );
}
