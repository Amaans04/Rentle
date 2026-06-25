# Rentle — Enterprise Architecture & Planning

> **Status:** Planning complete. Implementation must follow module dependency order.  
> **Current codebase:** Phase 1 MVP (Firebase + Next.js API + Flutter).  
> **Target:** Production SaaS competing with RentOk (PostgreSQL + Prisma + modular monorepo).

## Document Index

| # | Document | Purpose |
|---|----------|---------|
| 01 | [Product Requirements](./01-product-requirements.md) | Vision, scope, modules, success metrics |
| 02 | [User Personas](./02-user-personas.md) | Primary actors, goals, pain points |
| 03 | [User Flows](./03-user-flows.md) | End-to-end journeys per persona |
| 04 | [Information Architecture](./04-information-architecture.md) | Navigation, sitemaps, data hierarchy |
| 05 | [Database ER Diagram](./05-database-er-diagram.md) | Entity relationships (Mermaid) |
| 06 | [Prisma Schema](./06-prisma-schema.prisma) | Canonical PostgreSQL data model |
| 07 | [API Documentation](./07-api-documentation.md) | REST v1 contracts, auth, pagination |
| 08 | [Folder Structure](./08-folder-structure.md) | Monorepo layout (Turborepo) |
| 09 | [UI Wireframes](./09-ui-wireframes.md) | Screen layouts & component patterns |
| 10 | [Feature Dependency Graph](./10-feature-dependency-graph.md) | Build order & coupling |
| 11 | [Development Roadmap](./11-development-roadmap.md) | Phases 0–6, migration from MVP |
| 12 | [Sprint Planning](./12-sprint-planning.md) | First 6 sprints (2-week) |
| 13 | [Security Checklist](./13-security-checklist.md) | RBAC, tenancy, compliance |
| 14 | [Testing Strategy](./14-testing-strategy.md) | Unit, integration, E2E, load |
| 15 | [Deployment Strategy](./15-deployment-strategy.md) | Vercel, Railway, Supabase |
| 16 | [Monitoring Strategy](./16-monitoring-strategy.md) | Observability, alerts, SLOs |
| 17 | [Backup Strategy](./17-backup-strategy.md) | RPO/RTO, retention, drills |
| 18 | [Disaster Recovery Plan](./18-disaster-recovery-plan.md) | Failover, runbooks |

## Architecture Decision Records (Summary)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Multi-tenancy | Organization-scoped row isolation + PostgreSQL RLS | Proven at scale, auditable |
| API | NestJS (`apps/api`) | DDD modules, guards, queues, Swagger |
| Web | Next.js 15 App Router (`apps/web`) | Marketing + dashboards, SSR/SEO |
| Mobile | Flutter (`apps/mobile`) — retain | Existing investment; tenant/owner apps |
| Auth | Clerk (orgs + RBAC) | Enterprise SSO, session mgmt, DX |
| Database | Supabase PostgreSQL + Prisma | Managed Postgres, pooling, backups |
| Storage | Supabase Storage + signed URLs | Document uploads, virus-scan hook |
| Queue | BullMQ + Redis (Railway) | Notifications, billing, reports |
| Payments | Razorpay primary; Stripe adapter interface | India-first + export-ready |
| Caching | Redis + TanStack Query | API response cache, optimistic UI |

## Implementation Gate

**Do not write production feature code until:**

1. All 18 documents reviewed and signed off
2. Prisma schema migrated to `packages/database`
3. Auth + Organization + Property modules scaffolded with tests
4. CI pipeline green (lint, typecheck, unit tests)

## Next Step

Begin **Sprint 1** per [12-sprint-planning.md](./12-sprint-planning.md): monorepo scaffold + Auth + Organization + Property foundation.
