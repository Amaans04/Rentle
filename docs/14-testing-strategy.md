# 14 — Testing Strategy

---

## Testing Pyramid

```
        ┌─────────┐
        │   E2E   │  10% — Critical user journeys
        ├─────────┤
        │ Integr. │  25% — API + DB + queue
        ├─────────┤
        │  Unit   │  65% — Services, validators, utils
        └─────────┘
```

**Coverage targets:**
| Layer | Target |
|-------|--------|
| Domain services | ≥ 90% |
| Controllers | ≥ 80% |
| Repositories | ≥ 85% |
| UI components | ≥ 70% |
| E2E critical paths | 100% of listed flows |

---

## Unit Tests

**Framework:** Jest (API), Vitest (Web)

**What to test:**
- Bed status state machine transitions
- Invoice calculation (rent + charges + late fine)
- Proration on bed transfer
- Lead duplicate detection (phone normalization)
- Permission guard logic
- Zod schema edge cases

**Example:**
```typescript
describe('InvoiceService.generateMonthly', () => {
  it('applies late fine after grace period', () => { ... });
  it('skips archived tenancies', () => { ... });
});
```

---

## Integration Tests

**Framework:** Jest + Supertest (API)

**Setup:**
- Test database (Docker Postgres) — reset between suites
- Factory functions for Organization, Property, Bed, Tenancy
- Clerk test tokens (mocked in CI)

**Critical suites:**
| Suite | Tests |
|-------|-------|
| Tenancy isolation | Cross-org read returns 404 |
| Payment webhook | Duplicate webhook is idempotent |
| Bed delete | Blocked when occupied |
| Invite flow | Token expiry, single-use |
| Optimistic lock | Concurrent update returns 409 |

---

## E2E Tests

**Framework:** Playwright (Web), Patrol/Integration (Flutter)

**Critical paths (must always pass):**
1. Owner signup → create property → add bed
2. Invite tenant → onboard → bed occupied
3. Generate invoice → Razorpay test payment → receipt
4. Tenant submit complaint → staff resolve
5. Lead create → kanban move → convert

**Environment:** Staging with Razorpay test mode.

---

## API Contract Tests

- OpenAPI spec generated from NestJS
- Schemathesis or Dredd against staging
- Breaking change detection in CI (openapi-diff)

---

## Load Tests

**Tool:** k6

| Scenario | Target |
|----------|--------|
| Dashboard load | 500 concurrent users, p95 < 500ms |
| Public availability API | 1000 rps |
| Payment webhook burst | 100 webhooks/sec |
| Invoice generation cron | 10k tenancies in < 5 min |

Run before each major release.

---

## Security Tests

- OWASP ZAP scan on staging (weekly)
- Manual pen test before launch
- `npm audit` + Snyk in CI (fail on critical)

---

## Mobile Testing

| Type | Tool |
|------|------|
| Unit | flutter_test |
| Widget | golden tests for key screens |
| Integration | integration_test package |
| Device farm | Firebase Test Lab (release builds) |

---

## CI Pipeline

```yaml
on: [pull_request]
jobs:
  lint:       eslint + prettier check
  typecheck:  tsc --noEmit (all packages)
  unit:       jest --coverage (threshold 80%)
  integration: jest e2e (test DB)
  e2e:        playwright (main branch only)
  migrate:    prisma migrate diff (no drift)
```

---

## Test Data Management

- **Factories:** `@faker-js/faker` with deterministic seed in CI
- **Fixtures:** JSON snapshots for complex entities
- **Never:** Production data in tests
- **Seeding:** `pnpm db:seed` for local dev demo org

---

## Regression Policy

- Bug fix requires failing test first (TDD for bugs)
- Flaky test = P0 fix (quarantine max 48h)
- Release blocked if E2E critical path fails

---

## Manual QA Checklist (Release)

- [ ] Dark mode on new screens
- [ ] Mobile responsive breakpoints
- [ ] Keyboard navigation (command palette, forms)
- [ ] Screen reader on payment flow
- [ ] Hindi locale spot check (when enabled)
