# Rentle

B2B SaaS for PG (paying-guest hostel/co-living) operators in India.

Fresh rebuild — architecture and scope decisions are recorded in `docs/PROGRESS.md` and the approved plan at `~/.claude/plans/hey-hey-how-are-fuzzy-bee.md`.

## Structure

- `server/` — standalone Fastify (Node.js + TypeScript) API. No frontend framework involved. Deployable entirely on its own.
- `mobile/` — Flutter app (Android + iOS from one codebase). A pure client of `server/`'s API.
- `web/` — Next.js dashboard (built later). A pure client of `server/`'s API — no business logic lives here.

## Status

See `docs/PROGRESS.md` for current phase and what's next.
