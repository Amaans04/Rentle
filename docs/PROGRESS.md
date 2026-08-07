# Rentle — Progress

Living doc. Updated at the end of every phase. Full plan: `~/.claude/plans/hey-hey-how-are-fuzzy-bee.md`.

## Current phase: Phase 0 — Foundations

**Goal:** repo scaffold, Supabase + Clerk projects, Prisma schema v1, Fastify auth pipeline, RLS proven, cross-org isolation test suite in CI, `server/` deployed to Render.

### Done
- Git repo pushed to `github.com/Amaans04/Rentle` (private).
- `server/` Fastify + TypeScript project scaffolded — builds clean, typechecks clean, 0 npm vulnerabilities.
- `server/prisma/schema.prisma` — 22 models: full core-property-ops schema plus `Subscription`/`OrgFeatureFlag` for tier gating.
- **Supabase project live and migrated.** `app_user` role created (least-privilege, `NOSUPERUSER NOBYPASSRLS`), initial migration applied (all 22 tables exist), `prisma/rls.sql` applied for real.
- **Cross-org isolation proven against the live database, not skipped** — `RUN_DB_TESTS=true npm test` passes all 9 tests, including 3 that actually insert/query across two real orgs and confirm RLS blocks cross-org reads (ORM path and raw-SQL bypass attempt both blocked; same-org access still works).
- Auth pipeline (`src/auth/`): `authenticate`, `resolveOrg`, `requirePermission`, `requireFeature` (now correctly wrapped in `withOrgContext` — see gotcha below), `withOrgContext`.
- Clerk webhook (`src/routes/webhooks/clerk.ts`) — sole provisioning path for `User`/`Organization`/`OrganizationMember`.
- `/me`, `/internal/health` routes.
- `.github/workflows/ci.yml`, `.github/workflows/daily-jobs.yml`, `render.yaml`.

### Real gotchas hit and fixed while wiring Supabase (worth knowing if this ever needs redoing)
1. **Superuser bypasses RLS entirely** — the whole reason `app_user` exists instead of using the default `postgres` connection. Documented at the top of `rls.sql`.
2. **Supabase's pooler needs `role.project-ref` as the username** for the pooled connection (port 6543) — plain `app_user` fails; needs `app_user.<project-ref>`.
3. **Direct connections (port 5432) require IPv6** — Supabase's direct host has no A record on newer projects. Migrations use `directUrl` for this reason; if IPv6 isn't available, this can fail — use the pooler for everything if so.
4. **Prisma CLI (`db execute`) hung indefinitely** against this specific pooler in this environment for unclear reasons, even though raw TCP/TLS/Postgres-protocol tests (verified by hand with raw sockets and a real `pg` client) all worked instantly. `prisma migrate deploy`/`resolve` worked fine via `directUrl`; only ad hoc `db execute` calls hung. If this recurs, fall back to a raw `pg` client script rather than fighting the CLI.
5. **Migrations need more than `USAGE`/`SELECT,INSERT,UPDATE,DELETE`** — also needed `GRANT CREATE ON SCHEMA public` and, non-obviously, `GRANT CREATE ON DATABASE postgres` (required just for `CREATE SCHEMA IF NOT EXISTS "public"`, even though `public` already existed).
6. **Supabase installs extensions (`pgcrypto`, `citext`) into a schema literally called `extensions`, not `public`.** Prisma's connector pins `search_path` to `public` on every connection regardless of the role's own default search_path, so schema-qualifying in `schema.prisma` (`citext(schema: "extensions")`) was necessary — and even then, Prisma only schema-qualifies the `CREATE EXTENSION` statement, not column type references (`CITEXT` in a `CREATE TABLE`), which had to be hand-patched to `"extensions"."citext"` in the generated migration SQL. Also needed `GRANT USAGE ON SCHEMA extensions TO app_user`.
7. **`organizations` and `organization_members` are deliberately NOT RLS-protected**, unlike every other table — full reasoning is in the comment block at the top of `rls.sql`. Short version: both have a genuine chicken-and-egg problem (org creation happens before any org context can exist; `resolveOrg()` queries membership *to establish* context, so it can't require that context as a precondition). The isolation guarantee for these two comes from application-level checks (signature-verified webhook as sole writer; explicit `WHERE organizationId = ? AND userId = ?` in `resolveOrg`), not RLS. Every table holding actual tenant data keeps full RLS.
8. **Any Prisma query against an RLS-protected table must go through `withOrgContext`**, even ones that already have an explicit `WHERE organizationId = ...` filter in the query itself — RLS checks the session variable, not the query's own WHERE clause, so an unscoped connection returns zero rows regardless of what the query asks for. Caught and fixed one instance of this in `requireFeature` (was doing a plain `prisma.orgFeatureFlag.findUnique` instead of wrapping it). **This is the pattern every future Phase 1+ route handler must follow** — a good thing to double check in review.

### Blocked on you — still needed
1. **Clerk project** — enable Organizations, set email-OTP as the sign-in method (not phone, per the zero-cost decision). Get `CLERK_SECRET_KEY`/`CLERK_PUBLISHABLE_KEY`, create a webhook endpoint pointing at `<server-url>/webhooks/clerk` subscribed to `user.*`/`organization.*`/`organizationMembership.*`, get `CLERK_WEBHOOK_SECRET`.
2. **Render account** — connect the GitHub repo, it should pick up `render.yaml` automatically; fill in the secret env vars in the Render dashboard.
3. **GitHub repo secrets** — once the above exist, add all `.env` values as repo secrets (Settings → Secrets and variables → Actions) so `ci.yml` can run the DB-backed suite for real, plus `SERVER_URL` (the Render URL) for `daily-jobs.yml`.

### Next (after the above is unblocked)
- Deploy to Render, confirm `/internal/health` is reachable and requires the shared secret.
- Phase 1: Org/Property/Building/Floor/Room/Bed CRUD + bed-status-machine endpoint, staff invite + role assignment, audit-logging wired into every mutation.

## Decisions log

- 2026-08-07 — Full architecture locked: Postgres/Prisma/Supabase, Clerk auth, standalone Fastify server (not Next.js), Flutter mobile-first, multi-org from day one, "core property ops only" scope, 3-tier subscription structure (Starter/Growth/Business) benchmarked against RentOk/EazyPG. See the approved plan for full reasoning.
- 2026-08-07 — Phase 0 scaffold built locally (schema, auth pipeline, RLS SQL, tests, CI), pushed to GitHub.
- 2026-08-07 — Supabase fully wired: `app_user` role, migration applied, RLS applied and proven against live data. `organizations`/`organization_members` scoped out of RLS deliberately (see gotcha #7 above) — this is a considered design decision, not a shortcut.
