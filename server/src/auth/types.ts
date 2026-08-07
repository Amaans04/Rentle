import "fastify";
import type { Organization, OrganizationMember, User } from "@prisma/client";

// Populated by authenticate() and resolveOrg() in pipeline.ts. Anything
// downstream (requirePermission, requireFeature, route handlers) reads from
// here — never re-derives identity from raw request input.
declare module "fastify" {
  interface FastifyRequest {
    authUser?: User;
    orgContext?: {
      organization: Organization;
      member: OrganizationMember;
    };
  }
}
