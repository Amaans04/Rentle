# 11 — Development Roadmap

---

## Phase 0: Foundation (Weeks 1–3)

**Goal:** Monorepo scaffold, database, auth — no feature regression from MVP.

| Task | Deliverable |
|------|-------------|
| Turborepo + pnpm workspace | `apps/web`, `apps/api`, `packages/*` |
| Prisma schema deploy | Supabase PostgreSQL staging |
| Clerk integration | Org signup, JWT, webhooks |
| CI pipeline | Lint, typecheck, test on PR |
| Firebase migration script | Export `pgs`, `rooms`, `tenants` → SQL |
| Parallel API routing | Feature flag: legacy vs v1 API |
| Dev environment | Docker Compose (Postgres, Redis) |

**Exit criteria:** Clerk user creates org; property created in PostgreSQL; Flutter app can hit v1 health endpoint.

---

## Phase 1: Core Property (Weeks 4–6)

| Task | Deliverable |
|------|-------------|
| Property module (NestJS) | CRUD + validation |
| Building/Floor/Room/Bed | Full hierarchy |
| Bed status machine | Vacant ↔ Occupied ↔ Reserved |
| Owner dashboard (web) | Property list, bed grid |
| Flutter owner rooms | Migrate to v1 API |
| RBAC guards | Owner vs Manager scopes |
| Audit logging | All mutations logged |

**Exit criteria:** Owner manages 100 beds with correct status; delete blocked when occupied.

---

## Phase 2: Tenant Lifecycle (Weeks 7–10)

| Task | Deliverable |
|------|-------------|
| Tenancy module | Invite, onboard, active |
| Joining link + QR | Token-based onboarding |
| Document upload | Supabase signed URLs |
| Tenant mobile app | Home, profile, documents |
| Move-out workflow | Notice → settlement |
| Bed transfer | Prorated rent logic |
| Staff invites | Role assignment |

**Exit criteria:** End-to-end tenant onboarding without Firebase.

---

## Phase 3: Payments (Weeks 11–14)

| Task | Deliverable |
|------|-------------|
| Invoice generation | Monthly cron (BullMQ) |
| Custom charges | Electricity, food, fines |
| Razorpay integration | Orders, webhooks |
| Manual payments | UTR entry |
| Receipt PDF | Branded template |
| Tenant pay flow | Flutter + web |
| Collection dashboard | Owner KPIs |

**Exit criteria:** ₹1 test payment flows through Razorpay → invoice marked paid → ledger entry.

---

## Phase 4: Operations (Weeks 15–17)

| Task | Deliverable |
|------|-------------|
| Complaints module | Tickets, assignment |
| Notices module | Rich text, scheduling |
| Notification service | Email + push (FCM) |
| WhatsApp (MSG91/Gupshup) | Template messages |

**Exit criteria:** Tenant complaint → staff notification → resolution tracked.

---

## Phase 5: CRM & Booking (Weeks 18–22)

| Task | Deliverable |
|------|-------------|
| Lead CRM | Kanban, timeline, follow-ups |
| Duplicate detection | Phone normalization |
| Token payments | Lead → booking |
| Property website | CMS + public pages |
| Booking engine | Availability API |
| Custom domain | CNAME + Vercel |

**Exit criteria:** Website enquiry → lead → token → tenant conversion.

---

## Phase 6: Accounting & Reports (Weeks 23–26)

| Task | Deliverable |
|------|-------------|
| Ledger (double-entry) | Chart of accounts |
| Expenses module | Vendor payments |
| P&L report | Export PDF/CSV |
| Advanced analytics | Occupancy heatmap, funnel |
| GST-ready invoices | Line item tax fields |

---

## Phase 7: Platform & Scale (Weeks 27–30)

| Task | Deliverable |
|------|-------------|
| Subscription billing | Razorpay subscriptions |
| Super Admin panel | Org management |
| Feature flags | Per-org toggles |
| Visitors + Food + Attendance | Ops modules |
| Load testing | 1000 rps target |
| Security audit | Pen test remediation |
| Deprecate Firebase API | Full cutover |

---

## Migration Strategy (Firebase → PostgreSQL)

```
Week 1-2:  Dual-write (new writes → both DBs)
Week 3:    Read from PostgreSQL, verify parity
Week 4:    Read-only Firebase
Week 5:    Decommission Firebase (keep backup 90 days)
```

---

## Team Sizing Recommendation

| Phase | Engineers | Roles |
|-------|-----------|-------|
| 0–1 | 2–3 | 1 backend, 1 frontend, 0.5 DevOps |
| 2–4 | 4–5 | +1 mobile, +1 QA |
| 5–7 | 6–8 | +1 full-stack, +1 product designer |

---

## Current MVP Preservation

During Phase 0–2, existing `server/` + `mobile/` Firebase stack remains production for early users. New architecture builds in parallel — no big-bang rewrite.
