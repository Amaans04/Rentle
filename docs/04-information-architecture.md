# 04 — Information Architecture

---

## 1. Data Hierarchy (Multi-Tenancy)

```
Platform (Rentle)
└── Organization (billing + branding root)
    ├── Properties[]
    │   ├── Buildings[]
    │   │   └── Floors[]
    │   │       └── Rooms[]
    │   │           └── Beds[]
    │   ├── Tenancies[] (active tenant ↔ bed)
    │   ├── Leads[]
    │   ├── Bookings[]
    │   ├── Complaints[]
    │   ├── Notices[]
    │   ├── Visitors[]
    │   ├── Food Menus[]
    │   └── Property Website (CMS)
    ├── Staff Members[]
    ├── Organization Settings
    ├── Subscription & Billing
    └── Audit Logs[]
```

**Isolation rule:** Every query includes `organizationId`. Property-scoped resources also include `propertyId`.

---

## 2. Marketing Website (`rentle.com`)

```
/                     Home
/pricing              Plans
/features             Feature pages
/customers            Case studies
/blog                 CMS blog
/about
/contact
/login                → Clerk → redirect to app
/signup
/legal/privacy
/legal/terms
```

---

## 3. Owner / Manager Web App (`app.rentle.com`)

### Global Shell
- Command palette (⌘K): search tenants, rooms, leads, invoices
- Org switcher (multi-org users)
- Property switcher (scoped context)
- Notifications bell
- User menu (profile, settings, logout)

### Primary Navigation

| Section | Sub-pages |
|---------|-----------|
| **Dashboard** | Overview KPIs, recent activity, quick actions |
| **Properties** | List, detail, buildings, rooms, beds, floor plan |
| **Tenants** | List, detail, onboarding, move-out, archive |
| **Leads & CRM** | Kanban, list, detail, analytics |
| **Bookings** | Reservations, calendar, waitlist |
| **Payments** | Invoices, collections, pending, refunds |
| **Accounting** | Income, expenses, ledger, cashbook, P&L |
| **Reports** | Revenue, occupancy, collection, exports |
| **Complaints** | Inbox, detail, analytics |
| **Staff** | Directory, roles, attendance, salary |
| **Notices** | List, create, schedule |
| **Food** | Weekly menu, meal tracking |
| **Visitors** | Log, approvals, security view |
| **Attendance** | Tenant & staff |
| **Documents** | Templates, tenant docs |
| **Website** | Property CMS, domain, SEO |
| **Settings** | Org, branding, billing, integrations, notifications |

### Manager vs Owner
- Manager: property-scoped nav (assigned properties only)
- Owner: all properties + org settings + subscription

---

## 4. Tenant Mobile App

### Tab Navigation
1. **Home** — rent due, notices, quick pay
2. **Payments** — invoices, history, receipts
3. **Services** — complaints, food, visitors, attendance
4. **Profile** — documents, settings, support

### Deep Links
- `/pay/:invoiceId`
- `/complaint/:id`
- `/notice/:id`
- `/invite/:token` (onboarding)

---

## 5. Super Admin Panel (`admin.rentle.com`)

```
/dashboard          Platform KPIs (MRR, orgs, churn)
/organizations      CRUD, impersonate, suspend
/subscriptions      Plans, overrides
/payments           Platform billing
/support            Tickets
/feature-flags
/analytics
/audit-logs
/cms                Marketing content
/announcements      Platform-wide
```

---

## 6. Public Property Website (`{slug}.rentle.site` or custom domain)

```
/                   Hero, gallery, amenities
/rooms              Availability + pricing
/book               Reservation form
/reviews
/faq
/blog               Optional
/contact            Map, WhatsApp, call
/privacy
```

---

## 7. URL & Routing Conventions

| App | Pattern | Example |
|-----|---------|---------|
| Web dashboard | `/[orgSlug]/properties/[propertyId]/rooms` | `/acme-pg/properties/abc/rooms` |
| API | `/api/v1/organizations/:orgId/properties/:propertyId/...` | Versioned REST |
| Tenant API | `/api/v1/tenant/...` | Scoped to authenticated tenant |
| Public API | `/api/v1/public/properties/:slug/availability` | Rate-limited |

---

## 8. Search & Discovery

**Global search indexes (PostgreSQL + optional Typesense later):**
- Tenants (name, phone, room)
- Leads (name, phone, email)
- Invoices (number, tenant)
- Complaints (id, title)
- Rooms/Beds (number, status)

---

## 9. Content Types

| Type | Storage | CDN |
|------|---------|-----|
| Room photos | Supabase Storage | Cloudflare CDN |
| Tenant documents | Encrypted bucket | Signed URLs only |
| Invoice PDFs | Generated → Storage | Signed download |
| Agreement PDFs | Template + merge | Signed |
| Notice attachments | Storage | Org-scoped |

---

## 10. Notification Channels Matrix

| Event | In-App | Push | Email | SMS | WhatsApp |
|-------|--------|------|-------|-----|----------|
| Rent due | ● | ● | ● | ○ | ● |
| Payment received | ● | ● | ● | ○ | ○ |
| Complaint update | ● | ● | ○ | ○ | ○ |
| Visitor approval | ● | ● | ○ | ○ | ○ |
| Notice published | ● | ● | ● | ○ | ● |
| Lead follow-up | ○ | ○ | ○ | ● | ● |

● = default on | ○ = configurable
