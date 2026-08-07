# Rentle — Progress

Living doc. Updated at the end of every phase. Full plan: `~/.claude/plans/hey-hey-how-are-fuzzy-bee.md`.

## Current phase: Phase 0 — Foundations

**Goal:** repo scaffold, Supabase + Clerk projects, Prisma schema v1, Fastify auth pipeline, RLS proven, cross-org isolation test suite in CI, `server/` deployed to Render.

### Done
- Git repo, README, `.gitignore`.
- `server/` Fastify + TypeScript project scaffolded — builds clean (`npm run build`), typechecks clean (`npm run typecheck`), 0 npm vulnerabilities.
- `server/prisma/schema.prisma` — 22 models: full core-property-ops schema (org/property/building/floor/room/bed, tenancy lifecycle, invoicing, complaints/notices, staff) plus `Subscription`/`OrgFeatureFlag` for tier gating. Validated via `prisma generate`.
- `server/prisma/rls.sql` — Row Level Security policies for every organization-scoped table (direct + one-hop-via-parent). **Important gotcha documented at the top of that file: Supabase's default `postgres` connection is a superuser and always bypasses RLS — a dedicated `app_user` role must be created and used instead, or every policy is a no-op.**
- Auth pipeline (`src/auth/`): `authenticate` (Clerk token verification), `resolveOrg` (org membership check, orgId from URL path only — never trusted from body), `requirePermission` (static `ROLE_PERMISSIONS` matrix), `requireFeature` (static `TIER_FEATURES` matrix + `OrgFeatureFlag` override), `withOrgContext` (RLS `SET LOCAL` via `set_config`, parameterized — not string-interpolated).
- Clerk webhook (`src/routes/webhooks/clerk.ts`) — the only place local `User`/`Organization`/`OrganizationMember` rows are created; svix-signature-verified.
- `/me`, `/internal/health` routes.
- `PaymentGatewayProvider` / `StorageProvider` interfaces with manual/Supabase bindings (payment gateway itself still deferred, per plan).
- Test suite: 6 tests passing (auth-rejection paths, static no-custom-OTP regression check), 3 DB-backed isolation tests correctly skipping (gated behind `RUN_DB_TESTS=true`, not yet set — no live DB).
- `.github/workflows/ci.yml` (typecheck + test on push/PR) and `.github/workflows/daily-jobs.yml` (daily Supabase keep-alive ping; invoice-generation step commented in, to be uncommented in Phase 3).
- `render.yaml` blueprint for one-connect Render deployment.

### Blocked on you — external accounts I can't create on your behalf
1. **Supabase project** (Postgres + Storage). Once created:
   - Run `prisma migrate dev` (or `deploy`) against it to create tables.
   - Create the dedicated `app_user` role per the instructions at the top of `server/prisma/rls.sql`, then run that file against the DB as a superuser (`psql "$DIRECT_URL" -f server/prisma/rls.sql`).
   - Put `app_user`'s connection string (not the default `postgres` one) into `DATABASE_URL`/`DIRECT_URL`.
   - Get the project URL + service role key for `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`.
2. **Clerk project** — enable Organizations, set email-OTP as the sign-in method (not phone, per the zero-cost decision). Get `CLERK_SECRET_KEY`/`CLERK_PUBLISHABLE_KEY`, create a webhook endpoint pointing at `<server-url>/webhooks/clerk` subscribed to `user.*`/`organization.*`/`organizationMembership.*`, get `CLERK_WEBHOOK_SECRET`.
3. **GitHub remote repo** — push this repo, add the env vars above as repo secrets (Settings → Secrets and variables → Actions) so `ci.yml` and `daily-jobs.yml` can run for real. Also add `SERVER_URL` (the Render URL, once deployed) and set `RUN_DB_TESTS=true` once RLS is applied via `app_user`.
4. **Render account** — connect the repo, it should pick up `render.yaml` automatically; fill in the secret env vars in the Render dashboard (`sync: false` ones).

Once these four are in place, tell me and I'll verify the health endpoint is live and requires auth, confirm the isolation suite passes for real (not skipped), and move to Phase 1.

### Next (after the above is unblocked)
- Phase 1: Org/Property/Building/Floor/Room/Bed CRUD + bed-status-machine endpoint, staff invite + role assignment, audit-logging wired into every mutation.

## Decisions log

- 2026-08-07 — Full architecture locked: Postgres/Prisma/Supabase, Clerk auth, standalone Fastify server (not Next.js), Flutter mobile-first, multi-org from day one, "core property ops only" scope, 3-tier subscription structure (Starter/Growth/Business) benchmarked against RentOk/EazyPG. See the approved plan for full reasoning.
- 2026-08-07 — Phase 0 scaffold built locally (schema, auth pipeline, RLS SQL, tests, CI). Deployment/live-credential steps blocked on external account creation — see above.
