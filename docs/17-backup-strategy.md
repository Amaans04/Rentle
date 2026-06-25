# 17 — Backup Strategy

---

## Recovery Objectives

| Tier | RPO | RTO | Scope |
|------|-----|-----|-------|
| **Critical** (PostgreSQL) | 1 hour | 4 hours | All transactional data |
| **Important** (Storage) | 24 hours | 8 hours | Documents, images |
| **Standard** (Redis) | None* | 1 hour | Cache/queue — rebuildable |
| **Logs** | 0 (stream) | N/A | 90-day retention |

*Redis: queue jobs are retryable; no backup required. Persist job state in PostgreSQL for critical financial jobs.

---

## PostgreSQL (Supabase)

### Automated Backups
- **Daily** full backups (Supabase Pro: 7-day retention)
- **Point-in-Time Recovery (PITR)** — 7 days (upgrade to 30 days for Enterprise tier)
- WAL archiving continuous

### Manual Backups
- Weekly `pg_dump` to encrypted S3 bucket (cross-region: ap-south-1 → ap-southeast-1)
- Retention: 90 days weekly, 1 year monthly snapshots
- Pre-migration backup mandatory

### Verification
- Monthly restore drill to isolated staging DB
- Checksum validation after restore
- Document restore time in drill log

---

## Object Storage (Supabase Storage)

| Bucket | Backup Method | Retention |
|--------|---------------|-----------|
| `tenant-documents` | Daily incremental sync to S3 | 7 years (legal) |
| `room-photos` | Weekly full sync | 1 year |
| `invoice-pdfs` | Reproducible from DB — backup optional | 90 days |

Encryption: SSE-S3, bucket policies deny public access.

---

## Application Configuration

| Item | Backup |
|------|--------|
| Environment variables | Vercel/Railway export + 1Password vault |
| Clerk config | Export monthly |
| Razorpay webhook secrets | 1Password |
| DNS records | Cloudflare export weekly |
| Prisma migrations | Git (source of truth) |

---

## Backup Schedule Summary

| Job | Frequency | Destination |
|-----|-----------|-------------|
| Supabase PITR | Continuous | Supabase managed |
| pg_dump full | Weekly (Sun 02:00 IST) | S3 encrypted |
| Storage sync | Daily 03:00 IST | S3 cross-region |
| Config export | Monthly | 1Password |
| Restore drill | Monthly | Staging |

---

## Access Control

- Backup S3 bucket: IAM role only (no human access except break-glass)
- Break-glass access: 2-person approval, audited
- Encryption keys in AWS KMS (or Supabase managed)

---

## Compliance Retention

| Data Type | Retention |
|-----------|-----------|
| Financial records (invoices, payments) | 7 years |
| Tenant documents | Duration of tenancy + 3 years |
| Audit logs | 2 years online, 5 years archive |
| Application logs | 90 days |

---

## Backup Monitoring

- Alert if weekly pg_dump job fails
- Alert if backup size deviates > 20% from previous (possible corruption)
- Dashboard: last successful backup timestamp

---

## Pre-Release Checklist

- [ ] Fresh backup taken within 24h of deploy
- [ ] Migration tested on backup restore (staging)
- [ ] Rollback script ready
