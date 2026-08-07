# Rentle — Progress

Living doc. Updated at the end of every phase. Full plan: `~/.claude/plans/hey-hey-how-are-fuzzy-bee.md`.

## Phase 0 — Foundations: COMPLETE

**Goal:** repo scaffold, Supabase + Clerk projects, Prisma schema v1, Fastify auth pipeline, RLS proven, cross-org isolation test suite in CI, `server/` deployed to Render. **All exit criteria met — see plan §4.**

### Done
- Git repo pushed to `github.com/Amaans04/Rentle` (private).
- `server/` Fastify + TypeScript project — builds clean, typechecks clean, 0 npm vulnerabilities.
- `server/prisma/schema.prisma` — 22 models: full core-property-ops schema plus `Subscription`/`OrgFeatureFlag` for tier gating.
- **Supabase project live and migrated.** `app_user` role created (least-privilege, `NOSUPERUSER NOBYPASSRLS`), initial migration applied (all 22 tables exist), `prisma/rls.sql` applied for real.
- **Cross-org isolation proven against the live database — in CI, not just locally.** `RUN_DB_TESTS=true` is set as a GitHub Actions secret; every CI run now executes all 9 tests (0 skipped), including 3 that actually insert/query across two real orgs and confirm RLS blocks cross-org reads (ORM path and raw-SQL bypass attempt both blocked; same-org access still works).
- Auth pipeline (`src/auth/`): `authenticate`, `resolveOrg`, `requirePermission`, `requireFeature` (correctly wrapped in `withOrgContext`), `withOrgContext`.
- Clerk webhook (`src/routes/webhooks/clerk.ts`) — sole provisioning path for `User`/`Organization`/`OrganizationMember`. Live at `https://rentle-gdys.onrender.com/webhooks/clerk`, signing secret configured.
- `/me`, `/internal/health` (secret-protected, real DB round-trip), `/health` (public liveness check for Render) routes — all verified live in production.
- `.github/workflows/ci.yml` (runs on every push, `workflow_dispatch` for manual runs), `.github/workflows/daily-jobs.yml`, `render.yaml`.
- **`server/` deployed and live on Render**: `https://rentle-gdys.onrender.com`. Verified: public health check 200s, secret-protected route correctly rejects/accepts, unauthenticated `/me` correctly 401s, Render→Supabase connectivity confirmed in production.
- All 10 GitHub Actions repo secrets set (`DATABASE_URL`, `DIRECT_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `CLERK_SECRET_KEY`, `CLERK_PUBLISHABLE_KEY`, `CLERK_WEBHOOK_SECRET`, `INTERNAL_CRON_SECRET`, `SERVER_URL`, `RUN_DB_TESTS`).

### Real gotchas hit and fixed while wiring Supabase (worth knowing if this ever needs redoing)
1. **Superuser bypasses RLS entirely** — the whole reason `app_user` exists instead of using the default `postgres` connection. Documented at the top of `rls.sql`.
2. **Supabase's pooler needs `role.project-ref` as the username** for the pooled connection (port 6543) — plain `app_user` fails; needs `app_user.<project-ref>`.
3. **Direct connections (port 5432) require IPv6** — Supabase's direct host has no A record on newer projects. Migrations use `directUrl` for this reason; if IPv6 isn't available, this can fail — use the pooler for everything if so.
4. **Prisma CLI (`db execute`) hung indefinitely** against this specific pooler in this environment for unclear reasons, even though raw TCP/TLS/Postgres-protocol tests (verified by hand with raw sockets and a real `pg` client) all worked instantly. `prisma migrate deploy`/`resolve` worked fine via `directUrl`; only ad hoc `db execute` calls hung. If this recurs, fall back to a raw `pg` client script rather than fighting the CLI.
5. **Migrations need more than `USAGE`/`SELECT,INSERT,UPDATE,DELETE`** — also needed `GRANT CREATE ON SCHEMA public` and, non-obviously, `GRANT CREATE ON DATABASE postgres` (required just for `CREATE SCHEMA IF NOT EXISTS "public"`, even though `public` already existed).
6. **Supabase installs extensions (`pgcrypto`, `citext`) into a schema literally called `extensions`, not `public`.** Prisma's connector pins `search_path` to `public` on every connection regardless of the role's own default search_path, so schema-qualifying in `schema.prisma` (`citext(schema: "extensions")`) was necessary — and even then, Prisma only schema-qualifies the `CREATE EXTENSION` statement, not column type references (`CITEXT` in a `CREATE TABLE`), which had to be hand-patched to `"extensions"."citext"` in the generated migration SQL. Also needed `GRANT USAGE ON SCHEMA extensions TO app_user`.
7. **`organizations` and `organization_members` are deliberately NOT RLS-protected**, unlike every other table — full reasoning is in the comment block at the top of `rls.sql`. Short version: both have a genuine chicken-and-egg problem (org creation happens before any org context can exist; `resolveOrg()` queries membership *to establish* context, so it can't require that context as a precondition). The isolation guarantee for these two comes from application-level checks (signature-verified webhook as sole writer; explicit `WHERE organizationId = ? AND userId = ?` in `resolveOrg`), not RLS. Every table holding actual tenant data keeps full RLS.
8. **Any Prisma query against an RLS-protected table must go through `withOrgContext`**, even ones that already have an explicit `WHERE organizationId = ...` filter in the query itself — RLS checks the session variable, not the query's own WHERE clause, so an unscoped connection returns zero rows regardless of what the query asks for. Caught and fixed one instance of this in `requireFeature` (was doing a plain `prisma.orgFeatureFlag.findUnique` instead of wrapping it). **This is the pattern every future Phase 1+ route handler must follow** — a good thing to double check in review.

### One thing to double check
- Confirm `CLERK_WEBHOOK_SECRET` is also set in **Render's** Environment tab (it was added to `.env` and GitHub secrets, but Render was originally deployed before the webhook existed — make sure that value made it there too and the service redeployed after).

## Phase 1 — Property hierarchy + staff/RBAC: COMPLETE

**Goal:** Org/Property/Building/Floor/Room/Bed CRUD + bed-status-machine endpoint, staff invite + role assignment, audit-logging wired into every mutation. **All exit criteria met — see plan §4.**

### Done
- Shared route infra: `src/lib/http-errors.ts` (typed `HttpError`/`NotFoundError`/`ValidationError`/`ConflictError`, checked via `instanceof` in the global error handler), `src/lib/validation.ts` (`parseOrThrow` for zod schemas).
- `src/routes/organizations.ts` — GET/PATCH org, member list/update/deactivate.
- `src/routes/properties.ts` — full CRUD, with an explicit fix: `requirePermission`'s property-scope check only fires when `:propertyId` is in the URL, which POST (create) never has — so a property-scoped manager could otherwise create unrestricted new properties. Fixed with an explicit `member.propertyIds.length > 0` check in the handler.
- `src/routes/buildings-floors.ts`, `src/routes/rooms-beds.ts` — CRUD, rooms/beds flattened by `propertyId` with optional filters per plan §3 (not deep URL nesting).
- `src/services/bed-status.ts` + `PATCH /beds/:bedId/status` — the bed-status-machine endpoint. `OCCUPIED` is unreachable in either direction through this endpoint (only a Tenancy, Phase 2, can set it) — enforced in code now, tested, ready for Phase 2 to hook in.
- `src/routes/staff.ts` — invite endpoint calls Clerk's `createOrganizationInvitation` (coarse `org:member` Clerk role only — granular business role/propertyIds recorded in the audit log now, applied via `PATCH /members/:memberId` once they've joined, not pre-set through Clerk metadata); `StaffProfile` upsert/get for salary/joinDate.
- Every mutating route wraps its write in `withAudit` — verified by direct count, not just spot-checked (mutation-route count == `withAudit`-call count in every route file).
- **New test file** `tests/phase1-property-hierarchy.test.ts` — 8 tests against the live database (only Clerk's token *verification* is mocked, trusting Clerk's own well-tested implementation; everything downstream — RLS, authorization, business logic — runs for real). Covers: full property→building→floor→room→bed creation via API calls only; a property-scoped manager blocked from creating new properties, reading/writing outside their `propertyIds`, with the property list itself correctly filtered; the bed-status-machine rejecting manual `OCCUPIED` and requiring `blockedReason` for `BLOCKED`; every mutation producing an audit row. All 17 tests (9 from Phase 0 + 8 new) pass together; zero orphaned test data after cleanup.

### Next — Phase 2: Tenancy lifecycle
Tenancy CRUD + invite/onboarding-token flow, document upload via signed URLs, transfer/notice/move-out endpoints, `TenancyEvent` timeline, tenant self-auth via Clerk. This is also where `Bed.status` actually starts moving to/from `OCCUPIED`, hooking into the state machine built in Phase 1. See plan §4 for full exit criteria.

## Decisions log

- 2026-08-07 — Full architecture locked: Postgres/Prisma/Supabase, Clerk auth, standalone Fastify server (not Next.js), Flutter mobile-first, multi-org from day one, "core property ops only" scope, 3-tier subscription structure (Starter/Growth/Business) benchmarked against RentOk/EazyPG. See the approved plan for full reasoning.
- 2026-08-07 — Phase 0 scaffold built locally (schema, auth pipeline, RLS SQL, tests, CI), pushed to GitHub.
- 2026-08-07 — Supabase fully wired: `app_user` role, migration applied, RLS applied and proven against live data. `organizations`/`organization_members` scoped out of RLS deliberately (see gotcha #7 above) — this is a considered design decision, not a shortcut.
- 2026-08-07 — Clerk project created (Organizations enabled, email OTP + Google sign-in, phone number deliberately left off Clerk's sign-in options since Clerk now forces paid SMS verification the moment phone is enabled — collected as a plain unverified profile field in our own app instead). `server/` deployed to Render (`https://rentle-gdys.onrender.com`), Clerk webhook configured, all GitHub Actions secrets set. **Phase 0 complete.**
- 2026-08-08 — Timeline decision: the 3-PG free pilot ships on a **narrowed "Pilot v1" mobile scope** (core owner loop only, utilitarian UI, Android sideload, no app stores) rather than the full-scope Flutter app, to hit ~3–6 weeks pilot-ready instead of ~6–10+. Full mobile scope resumes post-pilot. See plan §4 Phase 5 for exact in/out-of-scope list.
- 2026-08-08 — **Phase 1 complete.** Property hierarchy + staff/RBAC API built and tested end-to-end against live Supabase, including the bed-status-machine and full audit-log coverage.
