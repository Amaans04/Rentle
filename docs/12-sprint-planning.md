# 12 — Sprint Planning (Revised)

**Sprint length:** 2 weeks  
**Focus:** Strengthen Firebase MVP — no infrastructure rewrite  
**Approved:** June 2025

---

## Architectural Constraints

- **Auth:** Custom JWT + Firebase (Clerk deferred)
- **Database:** Firestore (PostgreSQL/Prisma deferred)
- **Backend:** Next.js API routes (NestJS deferred)
- **Repo:** Keep `server/` + `mobile/` — no monorepo migration in Sprint 1
- **Principle:** Portable business logic via services + interfaces + adapters

---

## Sprint 1 — MVP Foundation Hardening

| Priority | Story | Status |
|----------|-------|--------|
| 1 | Production-ready OTP flow with `AUTH_MODE` / `OTP_BYPASS` flag | Done |
| 2 | Fix rent-record `/generate` route mismatch | Done |
| 3 | Standardized API response envelopes (`success: true`) | Done |
| 4 | Structured JSON logging | Done |
| 5 | Centralized error handling (`AppError` hierarchy) | Done |
| 6 | Firebase Storage provider abstraction | Done |
| 7 | Service/repository layer (`auth`, `rent`, `otp`) | Done |
| 8 | Integration stubs (Razorpay, SMS, Email, WhatsApp) | Done |
| 9 | Audit logging foundation | Done |
| 10 | Vitest unit tests (OTP + rent generation) | Done |

---

## Sprint 1 Exit Criteria

- [x] Flutter app works without API breaking changes
- [x] Next.js dashboard works (POST `/rent-records` preserved)
- [x] OTP bypass in exactly one place (`OtpService.validateOtpMatch`)
- [x] `OTP_BYPASS=false` enables strict OTP verification
- [ ] Manual smoke test: login → generate rent → view records

---

## Sprint 2 (Planned)

| Story | Points |
|-------|--------|
| Wire SMS adapter for OTP dispatch (MSG91) | 5 |
| Razorpay order creation for tenant payments | 8 |
| Document upload API using storage provider | 8 |
| Expand audit logging to room/tenant mutations | 5 |
| API integration tests with test Firestore emulator | 8 |
| Mobile: handle `success` envelope gracefully | 3 |

---

## Sprint 3+ (Parallel Enterprise Track)

Only after Sprint 1–2 stability:

- Prisma schema in `docs/` → isolated `packages/database` (no Firestore replacement)
- Marketing website scaffold
- Lead CRM module on Firestore with portable service layer

---

## Definition of Done

- [ ] Code reviewed
- [ ] Unit tests for new services
- [ ] No secrets in code
- [ ] `organizationId` / `pgId` scoping preserved
- [ ] Structured logs on auth + payment paths
- [ ] Backward-compatible API responses

---

## Environment Flags

| Variable | Default | Purpose |
|----------|---------|---------|
| `AUTH_MODE` | `development` | `production` = strict OTP |
| `OTP_BYPASS` | (derived) | Explicit override |
| `OTP_EXPIRY_MINUTES` | `10` | Session TTL |
| `OTP_MAX_ATTEMPTS` | `5` | Brute-force protection |

**Production cutover:** Set `AUTH_MODE=production` or `OTP_BYPASS=false` — no code changes required.
