# Rentle — Project Instructions

B2B SaaS for PG (paying-guest hostel/co-living) operators in India, competing with RentOk and EazyPG. Solo, pre-funding founder project.

## STATUS: HIBERNATED as of 2026-08-20

Paused indefinitely, not abandoned. Local build artifacts/caches were deleted to save disk (5.1GB → 3.2MB) — everything else is untouched and fully committed/pushed to `github.com/Amaans04/Rentle` `main` (`f39fa54`). `git log` on `main` is the authoritative record of what's built; this file is the map.

### How to get it running again

```
cd server && npm install        # rebuilds node_modules, dist/
cd mobile && flutter pub get    # rebuilds .dart_tool/, build/, Gradle cache, generated plugin files
```

`server/.env` was left in place (git-ignored, holds live DB/Clerk/Supabase creds) — check nothing has expired before assuming it still works. Server is already deployed and live at `https://rentle-gdys.onrender.com`; no redeploy needed just to resume local dev.

### What's actually done

- **Server (Phases 0–4): complete and deployed.** Fastify + TypeScript API on Render, Postgres/Prisma/Supabase with RLS proven in CI (not just locally), Clerk auth (orgs, email OTP), full CRUD for org→property→building→floor→room→bed, staff/RBAC, tenancy lifecycle (invite→active→notice→move-out), invoicing + manual payments, complaints, notices, tenant discovery (search-by-name + owner-approval join request). CI green, 0 npm vulnerabilities.
- **Mobile (Phase 5, "Pilot v1" scope): built, not yet pilot-verified.** Flutter, single codebase (Android + iOS). Full owner+tenant loop — property/room/bed setup, tenant onboarding, invoicing, payments, complaints, staff management, notices — all built beyond the original Pilot v1 minimum (staff UI and notices were originally deferred post-pilot, but got built anyway). Two visual design passes done (fonts, shared widgets, large titles, a real bottom-sheet duplicate-save fix). **Never run on a real device or through a real authenticated flow** — only verified via `flutter analyze`/`flutter test` and an iOS Simulator throwaway harness, because the Clerk `pk_test_...` publishable key was never supplied.
- **Full history and gotchas**: `docs/PROGRESS.md` (living doc, updated every phase — read this for the *why* behind anything non-obvious before re-diagnosing from scratch).
- **Original approved architecture plan**: `~/.claude/plans/hey-hey-how-are-fuzzy-bee.md` (locked stack decisions, full phase sequencing, verification checklist).

### Actual next step when resuming

Get the Clerk `pk_test_...` publishable key from the user, run the mobile app for real (simulator or device), verify the full owner+tenant flow end to end. That single unblock is the only thing standing between "built" and "pilot-ready."

### Future plans (not started, in priority order)

1. **Real-device / pilot verification** of the mobile app (above) — must happen before anything else, since it may surface real bugs the simulator can't.
2. **Phase 6 — Web dashboard** (`web/`, not yet scaffolded). Next.js on Vercel Hobby, pure API client — no business logic lives there, per the locked architecture decision.
3. **Get pilot PGs onto it** — original plan targeted 3 free pilot PGs for a 2-month feedback window once mobile is verified.
4. **Explicitly deferred, not forgotten** (schema already leaves seams for these — see plan §5): CRM/lead pipeline, booking engine + public property websites, double-entry accounting/ledger/expenses, visitor log, food menu, staff attendance, real notification infrastructure (in-app notices only today), platform super-admin/support tooling, live payment gateway integration (manual payment recording only today), phone-SMS login (email OTP only today, $0.01/msg on Clerk when it's worth turning on), subscription billing checkout flow (the tier/feature-gating *structure* itself is already built, just not wired to real billing).
5. **Post-pilot scale beyond the first 3 PGs** is explicitly a sales/rollout question, not an architecture one — multi-org/multi-property was built in from day one.

## Locked architecture decisions (do not relitigate without a real reason)

- DB: Postgres + Prisma via Supabase (free tier). Storage: Supabase Storage.
- Auth: Clerk (orgs/RBAC native — chosen specifically because hand-rolled RBAC broke two prior shelved attempts at this same product).
- Server: standalone Fastify (Node/TS) API, deliberately decoupled from any frontend. `web/` and `mobile/` are pure HTTP clients — never put business logic in them.
- Mobile: Flutter, single codebase for Android + iOS.
- Repo layout: `server/`, `mobile/`, `web/` as independent top-level projects. `docs/PROGRESS.md` updated at the end of every phase — keep doing this.
