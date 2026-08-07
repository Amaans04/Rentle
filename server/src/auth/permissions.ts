import type { OrgMemberRole } from "@prisma/client";

// Resource-scoped permission strings, not role-only booleans — per the PRD's
// RBAC model. Checked via requirePermission() in pipeline.ts.
export type Permission =
  | "organization:read"
  | "organization:write"
  | "member:read"
  | "member:write"
  | "property:read"
  | "property:write"
  | "room:read"
  | "room:write"
  | "bed:read"
  | "bed:write"
  | "tenancy:read"
  | "tenancy:write"
  | "document:read"
  | "document:write"
  | "invoice:read"
  | "invoice:write"
  | "payment:read"
  | "payment:write"
  | "complaint:read"
  | "complaint:write"
  | "notice:read"
  | "notice:write"
  | "staff:read"
  | "staff:write"
  | "audit:read"
  | "tenant-self:read"
  | "tenant-self:write";

const ALL_STAFF_READ: Permission[] = [
  "organization:read",
  "member:read",
  "property:read",
  "room:read",
  "bed:read",
  "tenancy:read",
  "document:read",
  "invoice:read",
  "payment:read",
  "complaint:read",
  "notice:read",
  "staff:read",
];

// Single static source of truth — one table to audit, not scattered checks.
export const ROLE_PERMISSIONS: Record<OrgMemberRole, Set<Permission>> = {
  OWNER: new Set([
    ...ALL_STAFF_READ,
    "organization:write",
    "member:write",
    "property:write",
    "room:write",
    "bed:write",
    "tenancy:write",
    "document:write",
    "invoice:write",
    "payment:write",
    "complaint:write",
    "notice:write",
    "staff:write",
    "audit:read",
  ]),
  MANAGER: new Set([
    ...ALL_STAFF_READ,
    "property:write",
    "room:write",
    "bed:write",
    "tenancy:write",
    "document:write",
    "invoice:write",
    "payment:write",
    "complaint:write",
    "notice:write",
    "staff:write",
    "audit:read",
  ]),
  RECEPTIONIST: new Set([
    ...ALL_STAFF_READ,
    "tenancy:write",
    "document:write",
    "complaint:write",
  ]),
  ACCOUNTANT: new Set([...ALL_STAFF_READ, "invoice:write", "payment:write"]),
  STAFF: new Set([...ALL_STAFF_READ, "complaint:write"]),
};

export function roleHasPermission(role: OrgMemberRole, permission: Permission): boolean {
  return ROLE_PERMISSIONS[role].has(permission);
}
