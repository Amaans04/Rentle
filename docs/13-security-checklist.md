# 13 — Security Checklist

---

## Authentication & Sessions

- [ ] Clerk handles primary auth (MFA available for owners)
- [ ] JWT validated on every API request (NestJS guard)
- [ ] Refresh token rotation (Clerk session management)
- [ ] Session listing + remote revoke (`UserSession` table)
- [ ] Login history with IP, device, geo (audit log)
- [ ] Impersonation requires Super Admin + audit trail + time limit
- [ ] OTP rate limiting (3/10min per phone) — retain from MVP
- [ ] Passwordless phone auth for tenants via Clerk or custom

## Authorization (RBAC)

- [ ] Permission strings: `resource:action` (e.g. `tenant:write`)
- [ ] Role templates: Owner, Manager, Receptionist, Accountant, Staff, Tenant
- [ ] Property-scoped access via `propertyIds[]` on membership
- [ ] Deny by default — explicit permission grants only
- [ ] API guards on every controller method
- [ ] UI hides actions user cannot perform (not security, UX)

## Multi-Tenancy Isolation

- [ ] `organizationId` on every tenant-scoped table
- [ ] Repository layer enforces org filter (never trust client)
- [ ] PostgreSQL Row Level Security policies (defense in depth)
- [ ] Integration tests: Org A cannot read Org B data
- [ ] Penetration test before public launch

## Input Validation

- [ ] Zod schemas on all API inputs (shared in `packages/shared`)
- [ ] Phone normalization (E.164 India)
- [ ] SQL injection: Prisma parameterized queries only
- [ ] XSS: sanitize rich text (notices) with DOMPurify
- [ ] CSRF: SameSite cookies + CSRF token on web mutations
- [ ] File upload: MIME whitelist, size limits, extension blocklist
- [ ] Image validation: magic bytes check, max dimensions

## API Security

- [ ] Rate limiting: 100 req/min authenticated, 60/min public
- [ ] Idempotency keys on payments
- [ ] Webhook signature verification (Razorpay, Clerk)
- [ ] CORS: allowlist only (`ALLOWED_ORIGINS`)
- [ ] Security headers: HSTS, CSP, X-Frame-Options, X-Content-Type-Options
- [ ] API versioning (`/v1/`) — breaking changes require new version
- [ ] No stack traces in production error responses

## Data Protection

- [ ] Encryption at rest (Supabase default AES-256)
- [ ] TLS 1.2+ everywhere
- [ ] Tenant documents: encrypted bucket + signed URLs (15min expiry)
- [ ] PII minimization in logs (mask phone, Aadhaar)
- [ ] DPDP Act: consent capture on document upload
- [ ] Data export + deletion API for tenant requests
- [ ] Document encryption key rotation plan

## Payments

- [ ] Never store card numbers — Razorpay tokenization only
- [ ] Webhook idempotency on `Payment.externalId`
- [ ] Amount validation server-side (never trust client amount)
- [ ] Reconciliation audit between Razorpay dashboard and ledger

## Infrastructure

- [ ] Secrets in environment variables / Vercel-Railway secret managers
- [ ] No `.env` in git (verified by pre-commit hook)
- [ ] Dependency scanning (Dependabot / Snyk)
- [ ] Container images scanned before deploy
- [ ] Least-privilege DB user (app user ≠ migration user)
- [ ] Redis password + VPC-only access in production

## Audit & Compliance

- [ ] `AuditLog` on all CREATE/UPDATE/DELETE
- [ ] Payment events logged
- [ ] Export actions logged
- [ ] Log retention: 2 years minimum
- [ ] SOC2-ready access controls documentation

## Virus Scanning (Ready Architecture)

- [ ] Upload → temp bucket → async scan job (ClamAV Lambda)
- [ ] Block download until `scanStatus: clean`
- [ ] Quarantine bucket for infected files

## Incident Response

- [ ] Security contact: security@rentle.com
- [ ] Breach notification playbook (72h DPDP)
- [ ] Token revocation procedure documented
- [ ] Annual security review scheduled

---

## Pre-Launch Gate

All items marked **Critical** must pass:

| Critical | Item |
|----------|------|
| ● | Multi-tenant isolation tested |
| ● | RBAC on all endpoints |
| ● | Payment webhook idempotency |
| ● | Signed document URLs only |
| ● | Rate limiting enabled |
| ● | Audit logs operational |
