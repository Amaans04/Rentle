import type { FastifyReply, FastifyRequest } from "fastify";
import { z } from "zod";
import { TenancyStatus } from "@prisma/client";
import { Errors } from "../lib/api-response.js";
import { prisma } from "../lib/prisma.js";
import { verifyClerkToken } from "./clerk.js";
import { withOrgContext } from "./db-context.js";
import { tierHasFeature, type FeatureKey } from "./features.js";
import { roleHasPermission, type Permission } from "./permissions.js";
import "./types.js";

const orgIdParamSchema = z.object({ orgId: z.string().min(1) });

/**
 * Step 1 of the pipeline. Verifies the Clerk bearer token and resolves it to
 * a LOCAL User row. That row must already exist — it is provisioned only by
 * the Clerk webhook (routes/webhooks/clerk.ts), never invented here from a
 * request field. A token for a Clerk user with no local row yet is treated
 * as unauthenticated (webhook lag, not a bug to work around by trusting the
 * client).
 */
export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const header = request.headers.authorization;
  const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : null;

  if (!token) {
    return reply.status(401).send(Errors.unauthorized());
  }

  const verified = await verifyClerkToken(token);
  if (!verified) {
    return reply.status(401).send(Errors.unauthorized());
  }

  const user = await prisma.user.findUnique({ where: { clerkId: verified.clerkUserId } });
  if (!user || user.deletedAt) {
    return reply.status(401).send(Errors.unauthorized());
  }

  request.authUser = user;
}

/**
 * Step 2. `orgId` is read ONLY from the URL path, never from the body or a
 * header — the direct fix for admin-login.js, which trusted a client-body
 * `sitePgId` and granted ownership with no membership check at all.
 * Membership is looked up server-side; if it doesn't exist, the request is
 * rejected regardless of what the client claims.
 */
export async function resolveOrg(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  if (!request.authUser) {
    return reply.status(401).send(Errors.unauthorized());
  }

  const parsed = orgIdParamSchema.safeParse(request.params);
  if (!parsed.success) {
    return reply.status(400).send(Errors.validation(parsed.error.flatten()));
  }

  const member = await prisma.organizationMember.findUnique({
    where: { organizationId_userId: { organizationId: parsed.data.orgId, userId: request.authUser.id } },
    include: { organization: true },
  });

  if (!member || !member.isActive || member.deletedAt || !member.organization || member.organization.deletedAt) {
    // 404, not 403 — do not confirm to the caller whether the org exists.
    return reply.status(404).send(Errors.notFound("Organization"));
  }

  request.orgContext = { organization: member.organization, member };
}

/**
 * Tenant equivalent of resolveOrg — tenants are never OrganizationMembers
 * (no RBAC role of their own; see the OrgMemberRole enum), so /tenant/*
 * routes use this instead. orgId still comes only from the URL path, same
 * reasoning as resolveOrg. The tenant's own active tenancy is derived
 * entirely from request.authUser.id server-side — never from a
 * client-supplied tenancyId, which is the whole point of this resolver
 * existing as a separate, narrower thing than resolveOrg.
 */
export async function resolveTenantContext(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  if (!request.authUser) {
    return reply.status(401).send(Errors.unauthorized());
  }

  const parsed = orgIdParamSchema.safeParse(request.params);
  if (!parsed.success) {
    return reply.status(400).send(Errors.validation(parsed.error.flatten()));
  }

  const organization = await prisma.organization.findUnique({ where: { id: parsed.data.orgId } });
  if (!organization || organization.deletedAt) {
    return reply.status(404).send(Errors.notFound("Organization"));
  }

  const tenancy = await withOrgContext(parsed.data.orgId, (tx) =>
    tx.tenancy.findFirst({
      where: {
        organizationId: parsed.data.orgId,
        userId: request.authUser!.id,
        deletedAt: null,
        status: { not: TenancyStatus.ARCHIVED },
      },
      orderBy: { createdAt: "desc" },
    })
  );
  if (!tenancy) {
    return reply.status(404).send(Errors.notFound("Tenancy"));
  }

  request.tenantContext = { organization, tenancy };
}

/**
 * Step 3. Static ROLE_PERMISSIONS lookup — one table to audit. Also checks
 * member.propertyIds for property-scoped roles when a :propertyId param is
 * present (empty array = all properties, i.e. owner-level access).
 */
export function requirePermission(permission: Permission) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    if (!request.orgContext) {
      return reply.status(401).send(Errors.unauthorized());
    }

    const { member } = request.orgContext;
    if (!roleHasPermission(member.role, permission)) {
      return reply.status(403).send(Errors.forbidden());
    }

    const propertyId = (request.params as Record<string, string | undefined>).propertyId;
    if (propertyId && member.propertyIds.length > 0 && !member.propertyIds.includes(propertyId)) {
      return reply.status(403).send(Errors.forbidden("You do not have access to this property."));
    }
  };
}

/**
 * Step 4. Subscription-tier feature gate. OrgFeatureFlag overrides are
 * consulted first (this is also how pilot orgs get everything unlocked for
 * free without a separate code path), falling back to the static
 * TIER_FEATURES matrix for the org's subscriptionTier.
 */
export function requireFeature(feature: FeatureKey) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    if (!request.orgContext) {
      return reply.status(401).send(Errors.unauthorized());
    }

    const { organization } = request.orgContext;

    // org_feature_flags is RLS-protected (unlike organizations/organization_members
    // — see the note in db-context.ts), so this lookup must run inside the
    // scoped transaction or it silently returns nothing regardless of the
    // WHERE clause below.
    const override = await withOrgContext(organization.id, (tx) =>
      tx.orgFeatureFlag.findUnique({
        where: { organizationId_flagKey: { organizationId: organization.id, flagKey: feature } },
      })
    );
    if (override) {
      if (!override.enabled) {
        return reply.status(403).send(Errors.featureLocked(feature));
      }
      return;
    }

    if (!tierHasFeature(organization.subscriptionTier, feature)) {
      return reply.status(403).send(Errors.featureLocked(feature));
    }
  };
}

/**
 * Convenience wrapper for handlers that need an RLS-scoped transaction.
 * Always call this instead of using `prisma` directly inside a route once
 * request.orgContext is set.
 */
export function withRequestOrgContext<T>(
  request: FastifyRequest,
  fn: Parameters<typeof withOrgContext<T>>[1]
): Promise<T> {
  if (!request.orgContext) {
    throw new Error("withRequestOrgContext called before resolveOrg");
  }
  return withOrgContext(request.orgContext.organization.id, fn);
}

/** Same as withRequestOrgContext, for routes using resolveTenantContext instead of resolveOrg. */
export function withRequestTenantContext<T>(
  request: FastifyRequest,
  fn: Parameters<typeof withOrgContext<T>>[1]
): Promise<T> {
  if (!request.tenantContext) {
    throw new Error("withRequestTenantContext called before resolveTenantContext");
  }
  return withOrgContext(request.tenantContext.organization.id, fn);
}
