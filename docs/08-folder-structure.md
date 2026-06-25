# 08 — Folder Structure

Turborepo monorepo replacing current flat `server/` + `mobile/` layout.

```
rentle/
├── apps/
│   ├── web/                          # Next.js 15 — marketing + dashboards
│   │   ├── app/
│   │   │   ├── (marketing)/          # rentle.com pages
│   │   │   │   ├── page.tsx
│   │   │   │   ├── pricing/
│   │   │   │   └── features/
│   │   │   ├── (auth)/               # Clerk auth routes
│   │   │   ├── (dashboard)/          # Owner/Manager app
│   │   │   │   └── [orgSlug]/
│   │   │   │       ├── layout.tsx
│   │   │   │       ├── dashboard/
│   │   │   │       ├── properties/
│   │   │   │       ├── tenants/
│   │   │   │       ├── leads/
│   │   │   │       ├── payments/
│   │   │   │       ├── reports/
│   │   │   │       └── settings/
│   │   │   ├── (admin)/              # Super admin panel
│   │   │   └── (sites)/              # Property microsites
│   │   │       └── [propertySlug]/
│   │   ├── components/
│   │   │   ├── ui/                   # shadcn/ui primitives
│   │   │   ├── layout/
│   │   │   ├── charts/
│   │   │   └── modules/              # Feature-specific UI
│   │   ├── hooks/
│   │   ├── lib/
│   │   └── middleware.ts             # Clerk + org routing
│   │
│   ├── api/                          # NestJS API server
│   │   ├── src/
│   │   │   ├── main.ts
│   │   │   ├── app.module.ts
│   │   │   ├── common/
│   │   │   │   ├── guards/           # Auth, RBAC, tenancy
│   │   │   │   ├── interceptors/     # Audit, transform
│   │   │   │   ├── filters/          # Exception handling
│   │   │   │   ├── decorators/
│   │   │   │   └── pipes/            # Zod validation
│   │   │   └── modules/
│   │   │       ├── auth/
│   │   │       │   ├── auth.controller.ts
│   │   │       │   ├── auth.service.ts
│   │   │       │   ├── auth.repository.ts
│   │   │       │   ├── dto/
│   │   │       │   └── auth.module.ts
│   │   │       ├── organization/
│   │   │       ├── property/
│   │   │       ├── room/
│   │   │       ├── bed/
│   │   │       ├── tenant/
│   │   │       ├── lead/
│   │   │       ├── booking/
│   │   │       ├── payment/
│   │   │       ├── invoice/
│   │   │       ├── accounting/
│   │   │       ├── complaint/
│   │   │       ├── notice/
│   │   │       ├── visitor/
│   │   │       ├── food/
│   │   │       ├── staff/
│   │   │       ├── notification/
│   │   │       ├── report/
│   │   │       ├── website/
│   │   │       ├── subscription/
│   │   │       ├── audit/
│   │   │       └── admin/
│   │   └── test/
│   │
│   └── mobile/                       # Flutter (existing, migrated)
│       └── lib/
│           ├── core/
│           ├── features/
│           │   ├── owner/
│           │   └── tenant/
│           └── repositories/
│
├── packages/
│   ├── database/                     # Prisma
│   │   ├── prisma/
│   │   │   ├── schema.prisma         # Copy from docs/06
│   │   │   └── migrations/
│   │   └── src/
│   │       └── index.ts              # Prisma client export
│   │
│   ├── shared/                       # Cross-app types & validators
│   │   ├── src/
│   │   │   ├── types/
│   │   │   ├── validators/           # Zod schemas
│   │   │   ├── constants/
│   │   │   └── utils/
│   │   └── package.json
│   │
│   ├── ui/                           # Shared React components (optional)
│   └── config/                       # ESLint, TS, Tailwind presets
│
├── infrastructure/
│   ├── docker/
│   │   ├── Dockerfile.api
│   │   └── docker-compose.yml        # Local: postgres, redis
│   ├── terraform/                    # Future IaC
│   └── scripts/
│       ├── migrate-firebase.ts       # Phase 0 data migration
│       └── seed.ts
│
├── docs/                             # This planning package
├── turbo.json
├── package.json
└── pnpm-workspace.yaml
```

---

## Module Internal Structure (NestJS)

Every domain module follows:

```
modules/tenant/
├── tenant.module.ts
├── tenant.controller.ts
├── tenant.service.ts
├── tenant.repository.ts
├── dto/
│   ├── create-tenancy.dto.ts
│   └── update-tenancy.dto.ts
├── validators/
│   └── tenancy.schema.ts
├── types/
│   └── tenancy.types.ts
├── events/
│   └── tenancy-created.event.ts
└── __tests__/
    ├── tenant.service.spec.ts
    └── tenant.e2e-spec.ts
```

---

## Web Feature Module Pattern

```
apps/web/components/modules/tenants/
├── tenant-list.tsx
├── tenant-detail-drawer.tsx
├── tenant-invite-dialog.tsx
├── use-tenants.ts              # TanStack Query hooks
└── tenant-columns.tsx          # Table column defs
```

---

## Naming Conventions

| Item | Convention |
|------|------------|
| Files | kebab-case |
| React components | PascalCase |
| API routes | plural nouns (`/tenancies`) |
| DB tables | snake_case (Prisma `@@map`) |
| Env vars | SCREAMING_SNAKE |
| Feature flags | `module.feature_name` |

---

## Current → Target Migration

| Current | Target |
|---------|--------|
| `server/src/app/api/*` | `apps/api/src/modules/*` |
| `server/src/app/(dashboard)/*` | `apps/web/app/(dashboard)/*` |
| `server/src/lib/firebase.ts` | `packages/database` + migration script |
| `mobile/lib/repositories/*` | Point to `api.rentle.com/v1` |

Keep `server/` running during Phase 0–1 parallel operation with feature flag routing.
