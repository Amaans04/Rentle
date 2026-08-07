-- Row Level Security policies — defense-in-depth on top of the app-level
-- `WHERE organizationId = ctx.organization.id` filter every query already
-- has. Run this AFTER `prisma migrate deploy` (Prisma doesn't manage RLS
-- policies itself).
--
-- NOTE ON IDENTIFIERS: Prisma generates camelCase column names by default
-- (no field-level @map in this schema), e.g. "organizationId" not
-- organization_id. Postgres folds unquoted identifiers to lowercase, so
-- every camelCase column reference below MUST be double-quoted or it will
-- silently resolve to the wrong (nonexistent) name. Table names ARE
-- snake_case (via @@map) and don't need quoting.
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
--   GRANT CREATE ON SCHEMA public TO app_user;         -- needed for migrate deploy
--   GRANT CREATE ON DATABASE postgres TO app_user;     -- needed for CREATE SCHEMA IF NOT EXISTS
--   GRANT USAGE ON SCHEMA extensions TO app_user;       -- Supabase installs extensions here, not public
--   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
--   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
--
-- Then set DATABASE_URL/DIRECT_URL to connect as app_user, not postgres.
-- This is a named Phase 0 exit-gate item — the RLS+pooler spike test must
-- run against app_user, not the default superuser connection, or it will
-- pass for the wrong reason.
-- ============================================================================

-- NOTE: `organizations` and `organization_members` are deliberately NOT
-- RLS-protected, unlike every other table here. Both have a genuine
-- chicken-and-egg problem a simple "row's org must match session org"
-- policy can't solve:
--   - `organizations` rows are created by the Clerk webhook (src/routes/
--     webhooks/clerk.ts) before any org context can exist — there's no
--     "current org" yet when the org itself is being provisioned.
--   - `organization_members` is what resolveOrg() (src/auth/pipeline.ts)
--     queries to ESTABLISH the org context in the first place — it can't
--     require that context to already be set as a precondition of finding
--     it.
-- This is a deliberate, narrow exception, not a gap in the isolation model:
--   - The webhook path is the only writer for both tables and is already
--     gated by svix signature verification (never trusts client input).
--   - resolveOrg() already does an explicit `WHERE organizationId = ? AND
--     userId = ?` filter in application code — the actual isolation
--     guarantee for membership lookups comes from that query being
--     correctly scoped, not from RLS.
--   - Every table that holds actual tenant DATA (tenancies, documents,
--     invoices, payments, complaints, etc.) keeps full RLS below — this
--     exception is limited to the two identity/membership tables that sit
--     structurally "above" any org context.

-- Tables with organizationId directly.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
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
    'audit_logs',
    'idempotency_keys'
  ]
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;

CREATE POLICY tenant_isolation ON subscriptions
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON org_feature_flags
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON properties
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON buildings
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON floors
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON rooms
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON beds
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON tenancies
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON invoices
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON payments
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON complaints
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON notices
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON audit_logs
  USING ("organizationId" = current_setting('app.current_org_id', true));

CREATE POLICY tenant_isolation ON idempotency_keys
  USING ("organizationId" = current_setting('app.current_org_id', true));

-- Child tables one hop from an organizationId-bearing parent (no direct
-- column, so policy is an EXISTS against the parent). These matter because
-- some carry sensitive data (tenant_documents holds Aadhaar/PAN references).

ALTER TABLE tenancy_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenancy_events FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON tenancy_events
  USING (EXISTS (
    SELECT 1 FROM tenancies t
    WHERE t.id = tenancy_events."tenancyId"
      AND t."organizationId" = current_setting('app.current_org_id', true)
  ));

ALTER TABLE tenant_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_documents FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON tenant_documents
  USING (EXISTS (
    SELECT 1 FROM tenancies t
    WHERE t.id = tenant_documents."tenancyId"
      AND t."organizationId" = current_setting('app.current_org_id', true)
  ));

ALTER TABLE invoice_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_line_items FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON invoice_line_items
  USING (EXISTS (
    SELECT 1 FROM invoices i
    WHERE i.id = invoice_line_items."invoiceId"
      AND i."organizationId" = current_setting('app.current_org_id', true)
  ));

ALTER TABLE payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_allocations FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON payment_allocations
  USING (EXISTS (
    SELECT 1 FROM payments p
    WHERE p.id = payment_allocations."paymentId"
      AND p."organizationId" = current_setting('app.current_org_id', true)
  ));

ALTER TABLE complaint_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_comments FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON complaint_comments
  USING (EXISTS (
    SELECT 1 FROM complaints c
    WHERE c.id = complaint_comments."complaintId"
      AND c."organizationId" = current_setting('app.current_org_id', true)
  ));

ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_profiles FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON staff_profiles
  USING (EXISTS (
    SELECT 1 FROM organization_members m
    WHERE m.id = staff_profiles."memberId"
      AND m."organizationId" = current_setting('app.current_org_id', true)
  ));

-- `users` is intentionally NOT RLS-protected here — a user's identity row is
-- not itself organization-scoped data (one user can belong to many orgs via
-- organization_members, which IS protected above).
