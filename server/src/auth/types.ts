import "fastify";
import type { Organization, OrganizationMember, Tenancy, User } from "@prisma/client";

// Populated by authenticate()/resolveOrg()/resolveTenantContext() in
// pipeline.ts. Anything downstream (requirePermission, requireFeature,
// route handlers) reads from here — never re-derives identity from raw
// request input.
declare module "fastify" {
  interface FastifyRequest {
    authUser?: User;
    orgContext?: {
      organization: Organization;
      member: OrganizationMember;
    };
    // Tenants aren't OrganizationMembers (no RBAC permissions of their
    // own), so /tenant/* routes use this instead of orgContext — see
    // resolveTenantContext.
    tenantContext?: {
      organization: Organization;
      tenancy: Tenancy;
    };
  }
}
