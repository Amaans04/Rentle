# 16 — Monitoring Strategy

---

## Observability Stack

| Layer | Tool |
|-------|------|
| APM | Sentry (errors + performance) |
| Logs | Axiom or Better Stack (structured JSON) |
| Metrics | Prometheus-compatible (Railway) + Grafana |
| Uptime | Better Uptime / Checkly |
| Analytics | PostHog (product) + Mixpanel (optional) |

---

## Service Level Objectives (SLOs)

| SLI | SLO | Error Budget |
|-----|-----|--------------|
| API availability | 99.9% monthly | 43 min downtime |
| API latency p95 | < 300ms | 5% requests may exceed |
| Payment webhook processing | 99.99% | 4 min/month |
| Dashboard LCP | < 2.5s | 10% sessions may exceed |

---

## What to Monitor

### Application Metrics
- Request rate, error rate, latency (by endpoint)
- Queue depth (BullMQ: notifications, invoices, webhooks)
- Payment webhook success/failure rate
- Active organizations, beds, tenancies (business metrics)

### Infrastructure Metrics
- CPU, memory, connection pool utilization
- PostgreSQL: slow queries (> 500ms), connection count
- Redis: memory, evictions
- Disk usage (Supabase)

### Security Metrics
- Failed auth attempts (spike alert)
- Rate limit hits
- Cross-tenant access attempts (should be 0)
- Impersonation sessions active

---

## Alerting Rules

| Alert | Condition | Channel | Severity |
|-------|-----------|---------|----------|
| API down | Health check fail 2 min | PagerDuty | P1 |
| Error rate spike | > 5% over 5 min | Slack #alerts | P1 |
| Payment webhook failures | > 3 in 10 min | Slack + PagerDuty | P1 |
| DB connections | > 80% pool | Slack | P2 |
| Queue backlog | > 1000 jobs 15 min | Slack | P2 |
| Disk space | > 85% | Email | P2 |
| Slow queries | > 10/min | Slack | P3 |

---

## Structured Logging Format

```json
{
  "level": "info",
  "timestamp": "2025-06-25T10:00:00Z",
  "service": "api",
  "traceId": "abc123",
  "organizationId": "org_xxx",
  "userId": "user_xxx",
  "action": "payment.webhook.processed",
  "duration_ms": 45,
  "metadata": { "paymentId": "pay_xxx", "amount": 8450 }
}
```

**Never log:** passwords, full Aadhaar, card numbers, JWT tokens.

---

## Distributed Tracing

- OpenTelemetry SDK in NestJS
- Trace ID propagated: Web → API → DB → Queue
- Sentry performance monitoring for slow transactions

---

## Dashboards

| Dashboard | Audience |
|-----------|----------|
| Platform Health | Engineering |
| Business KPIs | Product + Leadership |
| Payment Operations | Finance |
| Org-specific (future) | Owner (in-app analytics) |

---

## On-Call Rotation

- Primary + secondary engineer
- Business hours: 15 min response (P1)
- Off-hours: 30 min response (P1 payment/auth)
- Runbook links in PagerDuty incidents

---

## Synthetic Monitoring

Checkly monitors (every 5 min):
- `GET /health`
- `GET /api/v1/public/properties/demo/availability`
- Clerk login flow (staging)
- Razorpay test payment (staging, daily)

---

## Post-Incident Process

1. Incident channel + timeline
2. Customer communication if user-facing
3. Blameless postmortem within 48h
4. Action items tracked in Linear
