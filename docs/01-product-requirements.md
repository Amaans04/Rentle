# 01 — Product Requirements Document (PRD)

**Product:** Rentle  
**Version:** 2.0 (Enterprise)  
**Last Updated:** June 2025  
**Owner:** Product & Engineering  

---

## 1. Executive Summary

Rentle is a B2B SaaS platform for PG, hostel, and co-living operators in India. It replaces spreadsheets, WhatsApp chaos, and fragmented tools (RentOk, NoBrokerHood, etc.) with a unified operating system: property management, tenant lifecycle, payments, accounting, CRM, staff ops, and white-labelled tenant experiences.

**Positioning:** *"Stripe Dashboard meets Airbnb for PG operators."*

**Target scale:** 10,000+ organizations, 100,000+ properties, 1M+ tenants.

---

## 2. Problem Statement

| Stakeholder | Pain |
|-------------|------|
| Property Owner | No single source of truth; revenue leakage; manual rent chasing |
| Manager | Room/bed tracking on paper; complaint chaos; staff coordination |
| Accountant | No ledger; GST reconciliation manual; no audit trail |
| Tenant | Opaque billing; no digital receipts; poor communication |
| Sales (CRM) | Leads lost in WhatsApp; no funnel visibility |

---

## 3. Goals & Non-Goals

### Goals
- End-to-end property → bed → tenant lifecycle
- Automated rent billing with Indian payment rails
- Multi-property, multi-organization SaaS with strict isolation
- White-label property websites + booking engine
- Enterprise RBAC, audit logs, compliance-ready documents
- Premium UX (Linear/Stripe quality)

### Non-Goals (v1 Enterprise)
- Full ERP replacement (SAP-level)
- Native desktop apps
- International tax (beyond GST-ready structure)
- In-house payment acquiring (use Razorpay/Cashfree)

---

## 4. User Roles & Permissions (RBAC)

| Role | Scope | Key Permissions |
|------|-------|-----------------|
| **Super Admin** | Platform | Orgs, billing, feature flags, impersonation |
| **Owner** | Organization | Full org access, billing, branding |
| **Manager** | Property(ies) | Tenants, rooms, staff, reports |
| **Receptionist** | Property | Check-in, visitors, leads |
| **Accountant** | Org/Property | Payments, ledger, expenses |
| **Staff** | Assigned tasks | Attendance, complaints assigned |
| **Tenant** | Self | Pay rent, complaints, notices, profile |

Permissions are **resource-scoped** (`property:read`, `tenant:write`, `payment:approve`) — not role-only booleans.

---

## 5. Functional Requirements by Module

### 5.1 Core Platform
- **FR-CORE-01:** Organization signup with Clerk; invite staff
- **FR-CORE-02:** Multi-property under one organization
- **FR-CORE-03:** Custom branding (logo, colors, domain)
- **FR-CORE-04:** Audit log on all mutating operations
- **FR-CORE-05:** Feature flags per organization (Super Admin)

### 5.2 Property Management
- **FR-PROP-01:** Property → Building → Floor → Room → Bed hierarchy
- **FR-PROP-02:** Bed states: Vacant, Occupied, Reserved, Blocked, Maintenance, Cleaning
- **FR-PROP-03:** Room photos, amenities, dynamic pricing (MRP, rent, discounts)
- **FR-PROP-04:** Availability calendar & floor plan (Phase 2)

### 5.3 Tenant Management
- **FR-TEN-01:** Digital onboarding via link/QR
- **FR-TEN-02:** Document upload (Aadhaar, PAN, etc.) with validation hooks
- **FR-TEN-03:** Rental agreement + e-sign integration ready
- **FR-TEN-04:** Room/bed transfer, notice period, move-out, blacklist
- **FR-TEN-05:** Tenant timeline (immutable event stream)

### 5.4 Lead CRM
- **FR-CRM-01:** Kanban pipeline with customizable stages
- **FR-CRM-02:** Lead source, notes, timeline, follow-ups
- **FR-CRM-03:** Visit/call scheduling; WhatsApp integration
- **FR-CRM-04:** Token payment → booking conversion
- **FR-CRM-05:** Duplicate detection (phone/email)
- **FR-CRM-06:** Sales analytics & funnel reports

### 5.5 Booking Engine
- **FR-BOOK-01:** Public property website per property
- **FR-BOOK-02:** Bed reservation with availability check
- **FR-BOOK-03:** SEO, gallery, maps, reviews, FAQ
- **FR-BOOK-04:** Custom domain (CNAME + SSL)

### 5.6 Payments & Billing
- **FR-PAY-01:** Monthly rent auto-generation (cron)
- **FR-PAY-02:** Custom charges (electricity, food, laundry)
- **FR-PAY-03:** Late fine, grace period
- **FR-PAY-04:** Razorpay/Cashfree checkout + webhooks
- **FR-PAY-05:** Manual payment entry, UPI QR, refunds
- **FR-PAY-06:** Invoice PDF, receipt email/WhatsApp
- **FR-PAY-07:** Tenant ledger (double-entry ready)

### 5.7 Accounting
- **FR-ACC-01:** Income/expense categories
- **FR-ACC-02:** Vendor payments, salary, cashbook
- **FR-ACC-03:** P&L, export CSV/Excel/PDF
- **FR-ACC-04:** GST-ready line items (Phase 2: filing)

### 5.8 Operations
- **Complaints:** Tickets, priority, assignment, escalation, photos
- **Notices:** Rich text, scheduling, audience, push/WhatsApp/SMS
- **Food:** Weekly menu, skip meal, kitchen dashboard
- **Visitors:** Approval workflow, QR pass, entry/exit log
- **Attendance:** Tenant/staff check-in, leave requests

### 5.9 Staff Management
- Profiles, roles, attendance, leaves, salary, tasks, activity logs

### 5.10 Reports & Analytics
- Revenue, occupancy, collection, lead conversion, complaints, exports
- Platform analytics (MRR, ARR, churn) for Super Admin

### 5.11 Notifications
- Email, SMS, WhatsApp, push, in-app
- Preferences, history, retry queue (BullMQ)

---

## 6. Non-Functional Requirements

| Category | Requirement |
|----------|-------------|
| **Availability** | 99.9% uptime SLA (paid tiers) |
| **Latency** | API p95 < 300ms; dashboard LCP < 2.5s |
| **Scale** | 10k concurrent dashboard users |
| **Security** | SOC2-ready controls; encryption at rest/transit |
| **Compliance** | DPDP Act awareness; consent for documents |
| **Accessibility** | WCAG 2.1 AA on web dashboards |
| **Localization** | English + Hindi (Phase 2) |
| **Data residency** | India region (Supabase Mumbai when available) |

---

## 7. Success Metrics (KPIs)

| Metric | Year 1 Target |
|--------|---------------|
| Organizations onboarded | 500 |
| Properties managed | 2,000 |
| Monthly active tenants | 50,000 |
| Rent collected via platform | ₹10 Cr/month |
| Lead → tenant conversion | 25% |
| NPS (owners) | > 50 |
| Churn (monthly) | < 3% |

---

## 8. Subscription Tiers (SaaS)

| Tier | Properties | Beds | Features |
|------|------------|------|----------|
| **Starter** | 1 | 50 | Core PM, payments, tenant app |
| **Growth** | 5 | 250 | CRM, reports, white-label website |
| **Business** | 25 | 1,500 | Accounting, API, custom domain |
| **Enterprise** | Unlimited | Unlimited | SSO, SLA, dedicated support |

Billing via Razorpay Subscriptions; usage metering on beds.

---

## 9. Migration from Phase 1 MVP

Existing Firebase collections (`pgs`, `rooms`, `tenants`, etc.) map to:
- `pgs` → `Organization` + `Property`
- `rooms` → `Room` + `Bed` (split occupancy to bed level)
- `tenants` → `Tenant` + `Tenancy`
- `rentRecords` → `Invoice` + `Payment`

Migration script required in Phase 0 (see Roadmap).

---

## 10. Out of Scope / Future

- IoT smart lock integration
- AI rent pricing optimizer
- Marketplace for vacant beds across orgs
- Franchise multi-org hierarchies

---

## 11. Acceptance Criteria (Platform Ready)

- [ ] New org can onboard property, add beds, invite tenant, collect rent end-to-end
- [ ] Zero cross-tenant data leakage (penetration tested)
- [ ] All mutations audited
- [ ] Payment webhook idempotency verified
- [ ] 80% unit test coverage on domain services
- [ ] Load test: 1000 req/s on read-heavy dashboard APIs
