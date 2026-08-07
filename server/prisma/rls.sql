-- Row Level Security policies — defense-in-depth on top of the app-level
-- `WHERE organizationId = ctx.organization.id` filter every query already
-- has. Run this AFTER `prisma migrate deploy` (Prisma doesn't manage RLS
-- policies itself): `psql "$DIRECT_URL" -f prisma/rls.sql`
--
-- ============================================================================
-- CRITICAL — READ BEFORE RUNNING
-- ============================================================================
-- Supabase's default `postgres` connection role is a SUPERUSER and always
-- bypasses Row Level Security, no matter how these policies are written —
-- including with FORCE ROW LEVEL SECURITY. If the app's DATABASE_URL/
-- DIRECT_URL connect as `postgres`, every policy below is a no-op and
-- multi-tenant isolation is enforced by app-level code ALONE — exactly the
-- "convention, no DB-level backstop" gap both prior projects had.
--
-- Before relying on any of this, create a dedicated least-privilege role for
-- the app to connect as, and use ITS connection string in .env instead of
-- the default `postgres` one:
--
--   CREATE ROLE app_user WITH LOGIN PASSWORD '<generate a strong one>' NOSUPERUSER NOBYPASSRLS;
--   GRANT USAGE ON SCHEMA public TO app_user;
--   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
--   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
--
-- Then set DATABASE_URL/DIRECT_URL to connect as app_user, not postgres.
-- This is a named Phase 0 exit-gate item — the RLS+pooler spike test must
-- run against app_user, not the default superuser connection, or it will
-- pass for the wrong reason.
-- ============================================================================

-- Tables with organizationId directly.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'organizations', -- note: policy below is special-cased (matches on id, not organization_id)
    'organization_members',
    'subscriptions',
    'org_feature_flags',
    'properties',
    'buildings',
    'floors',
    'rooms',
    'beds',
    'tenancies',
    'invoices',
    'payments',
    'complaints',
    'notices',
    'audit_logs'
  ]
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

CREATE POLICY tenant_isolation ON organizations
  USING (id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON organization_members
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON subscriptions
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON org_feature_flags
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON properties
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON buildings
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON floors
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON rooms
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON beds
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON tenancies
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON invoices
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON payments
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON complaints
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON notices
  USING (organization_id = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON audit_logs
  USING (organization_id = current_setting('app.current_org_id', true));

-- Child tables one hop from an organizationId-bearing parent (no direct
-- column, so policy is an EXISTS against the parent). These matter because
-- some carry sensitive data (tenant_documents holds Aadhaar/PAN references).

ALTER TABLE tenancy_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenancy_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON tenancy_events
  USING (EXISTS (
    SELECT 1 FROM tenancies t
    WHERE t.id = tenancy_events.tenancy_id
      AND t.organization_id = current_setting('app.current_org_id', true)
  ));

ALTER TABLE tenant_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_documents FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON tenant_documents
  USING (EXISTS (
    SELECT 1 FROM tenancies t
    WHERE t.id = tenant_documents.tenancy_id
      AND t.organization_id = current_setting('app.current_org_id', true)
  ));

ALTER TABLE invoice_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_line_items FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON invoice_line_items
  USING (EXISTS (
    SELECT 1 FROM invoices i
    WHERE i.id = invoice_line_items.invoice_id
      AND i.organization_id = current_setting('app.current_org_id', true)
  ));

ALTER TABLE payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_allocations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON payment_allocations
  USING (EXISTS (
    SELECT 1 FROM payments p
    WHERE p.id = payment_allocations.payment_id
      AND p.organization_id = current_setting('app.current_org_id', true)
  ));

ALTER TABLE complaint_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_comments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON complaint_comments
  USING (EXISTS (
    SELECT 1 FROM complaints c
    WHERE c.id = complaint_comments.complaint_id
      AND c.organization_id = current_setting('app.current_org_id', true)
  ));

ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_profiles FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON staff_profiles
  USING (EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.id = staff_profiles.member_id
      AND m.organization_id = current_setting('app.current_org_id', true)
  ));

-- `users` is intentionally NOT RLS-protected here — a user's identity row is
-- not itself organization-scoped data (one user can belong to many orgs via
-- organization_members, which IS protected above).
