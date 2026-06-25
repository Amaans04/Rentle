# 18 — Disaster Recovery Plan

---

## Disaster Scenarios

| Scenario | Likelihood | Impact | Recovery |
|----------|------------|--------|----------|
| Supabase region outage | Low | Critical | Failover to restore |
| Railway API crash | Medium | High | Auto-restart + rollback |
| Data corruption | Low | Critical | PITR restore |
| Razorpay outage | Medium | Medium | Manual payment mode |
| Clerk outage | Low | High | Cached JWT grace (15 min) |
| DDoS attack | Medium | Medium | Cloudflare mitigation |
| Accidental data deletion | Medium | High | PITR + soft delete |
| Complete AWS/Supabase account compromise | Very Low | Critical | Break-glass restore |

---

## Recovery Time / Point Summary

| Asset | RPO | RTO |
|-------|-----|-----|
| PostgreSQL | 1 hour | 4 hours |
| API service | N/A | 15 minutes |
| Web (Vercel) | N/A | 5 minutes |
| Document storage | 24 hours | 8 hours |
| Full platform | 1 hour | 6 hours |

---

## Runbook 1: Database Failure / Corruption

### Detection
- Health check fails DB ping
- Sentry alerts on connection errors
- Supabase status page

### Response (0–15 min)
1. Confirm incident in `#incidents` Slack channel
2. Assign Incident Commander
3. Enable maintenance mode page on Vercel
4. Stop write traffic: scale API to 0 or enable read-only flag

### Recovery (15 min – 4 hr)
1. Identify corruption scope (table vs full)
2. **Partial:** PITR to specific timestamp before incident
3. **Full:** Restore latest weekly pg_dump to new Supabase project
4. Update `DATABASE_URL` in Railway (staging first, verify)
5. Run `prisma migrate deploy` if needed
6. Data parity check script (row counts per org)
7. Promote to production DNS
8. Disable maintenance mode

### Post-Recovery
- Notify affected customers if data loss > 1 hour
- Postmortem within 48 hours

---

## Runbook 2: API Service Outage

### Detection
- Uptime monitor failure
- Error rate 100%

### Response
1. Check Railway logs + Sentry
2. Rollback to last known good deployment (< 2 min)
3. If rollback fails: redeploy from `main` tag
4. Verify health + smoke tests
5. If Redis down: API degrades gracefully (no cache, queue pauses)

**RTO target:** 15 minutes

---

## Runbook 3: Payment System Failure

### Razorpay Down
1. Display banner: "Online payments temporarily unavailable"
2. Enable manual UPI payment instructions (org UPI ID)
3. Managers can mark payments paid with UTR
4. Queue webhook replay when Razorpay recovers (store raw payloads)

### Double Charge / Webhook Storm
1. Idempotency keys prevent duplicates
2. Reconciliation job compares Razorpay settlement vs ledger
3. Manual refund via Razorpay dashboard + ledger adjustment

---

## Runbook 4: Security Breach

### Detection
- Anomalous cross-tenant access in audit logs
- Clerk security alert
- Customer report

### Immediate (0–1 hr)
1. Revoke all sessions (`Clerk` + `UserSession` table)
2. Rotate all secrets (JWT, Razorpay, DB password)
3. Enable enhanced audit logging
4. Preserve forensic logs (do not delete)

### Investigation (1–24 hr)
1. Identify breach vector
2. Scope of data accessed
3. Legal/compliance notification (DPDP: 72 hours if PII breach)

### Recovery
1. Patch vulnerability
2. Force password re-auth for all users
3. Customer communication template
4. External security audit

---

## Runbook 5: Firebase MVP Cutover Rollback

During migration period only:

1. Feature flag `API_SOURCE=firebase` on mobile + web
2. PostgreSQL remains read-only copy
3. Resume Firebase writes
4. Investigate migration issue
5. Re-attempt cutover after fix

---

## Communication Templates

### Status Page (Minor)
> We're experiencing elevated error rates on payment processing. Manual UPI payments are available. ETA: 30 minutes.

### Status Page (Major)
> Rentle is currently unavailable. Our team is working on recovery. No action needed from your side. Updates every 30 minutes.

### Post-Incident Email
> Subject: Incident resolved — [Date]  
> What happened, impact, resolution, prevention steps.

---

## DR Testing Schedule

| Test | Frequency | Owner |
|------|-----------|-------|
| DB restore to staging | Monthly | Backend lead |
| API rollback drill | Quarterly | DevOps |
| Full DR simulation | Annually | Engineering + Product |
| Payment failover (manual mode) | Quarterly | Backend |
| Security breach tabletop | Annually | All eng |

---

## Escalation Matrix

| Severity | Example | Response | Escalate to |
|----------|---------|----------|-------------|
| SEV1 | Platform down, payments broken | 15 min | CTO + Founder |
| SEV2 | Single module degraded | 1 hr | Eng lead |
| SEV3 | Non-critical bug | Next sprint | Team |

---

## DR Infrastructure (Future)

When scale warrants:
- Read replica in secondary region (Supabase read replica)
- Multi-region API (Railway + Fly.io standby)
- Cloudflare load balancing with health checks

**Trigger:** > 5000 organizations OR 99.9% SLO breach twice in quarter.

---

## Contacts

| Role | Responsibility |
|------|----------------|
| Incident Commander | Coordinates response |
| Comms Lead | Customer + status page updates |
| Technical Lead | Executes runbook |
| Legal/Compliance | Breach notification |

Maintain contact list in 1Password (not in repo).
