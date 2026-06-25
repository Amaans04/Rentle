# 05 — Database ER Diagram

> Canonical schema: [06-prisma-schema.prisma](./06-prisma-schema.prisma)

---

## Core Entity Relationship (High Level)

```mermaid
erDiagram
    Organization ||--o{ Property : owns
    Organization ||--o{ OrganizationMember : has
    Organization ||--o{ Subscription : bills
    User ||--o{ OrganizationMember : belongs

    Property ||--o{ Building : contains
    Building ||--o{ Floor : has
    Floor ||--o{ Room : has
    Room ||--o{ Bed : has

    Property ||--o{ Lead : tracks
    Property ||--o{ Tenancy : hosts
    Bed ||--o| Tenancy : "occupied by"
    User ||--o| Tenancy : "tenant user"

    Tenancy ||--o{ Invoice : generates
    Invoice ||--o{ InvoiceLineItem : contains
    Invoice ||--o{ Payment : receives
    Payment ||--o{ LedgerEntry : posts

    Property ||--o{ Complaint : has
    Property ||--o{ Notice : publishes
    Property ||--o{ VisitorLog : logs
    Property ||--o{ FoodMenu : serves

    Organization ||--o{ Expense : records
    Organization ||--o{ AuditLog : audits
```

---

## Tenant Lifecycle

```mermaid
erDiagram
    Lead ||--o| Booking : converts
    Booking ||--o| Tenancy : creates
    Tenancy ||--o{ TenancyEvent : timeline
    Tenancy ||--o{ TenantDocument : stores
    Tenancy ||--o| Agreement : signs
    Tenancy }o--|| Bed : occupies
```

---

## Payments & Accounting

```mermaid
erDiagram
    Invoice ||--o{ InvoiceLineItem : has
    Payment ||--o{ PaymentAllocation : allocates
    PaymentAllocation }o--|| Invoice : pays
    LedgerAccount ||--o{ LedgerEntry : contains
    LedgerEntry }o--|| Payment : source
    Expense }o--|| LedgerAccount : category
```

---

## CRM Pipeline

```mermaid
erDiagram
    Lead ||--o{ LeadNote : has
    Lead ||--o{ LeadFollowUp : schedules
    Lead ||--o{ LeadActivity : timeline
    Lead }o--o| User : "assigned to"
    Lead }o--o| Property : "interested in"
    Lead }o--o| Bed : "reserved"
    Lead ||--o| Payment : "token payment"
```

---

## Multi-Tenancy Enforcement

```mermaid
flowchart LR
    subgraph Every Table
        A[organizationId UUID NOT NULL]
        B[Index on organizationId]
        C[FK to Organization]
    end
    subgraph PostgreSQL RLS
        D[Policy: org_id = current_setting]
    end
    A --> D
```

---

## Key Indexes (Performance)

| Table | Index | Purpose |
|-------|-------|---------|
| `tenancies` | `(organizationId, propertyId, status)` | Active tenant lists |
| `beds` | `(roomId, status)` | Availability queries |
| `invoices` | `(organizationId, dueDate, status)` | Collection reports |
| `payments` | `(organizationId, paidAt)` | Revenue analytics |
| `leads` | `(organizationId, stage, assignedToId)` | CRM kanban |
| `audit_logs` | `(organizationId, createdAt DESC)` | Activity feed |
| `notifications` | `(userId, readAt, createdAt)` | Inbox |

---

## Soft Delete Strategy

Tables with `deletedAt`:
- `organizations`, `properties`, `rooms`, `beds`, `tenancies`, `leads`, `staff_profiles`

Hard delete only for:
- OTP tokens, session tokens, ephemeral queue jobs

---

## Optimistic Locking

Tables with `version Int @default(1)`:
- `tenancies`, `invoices`, `payments`, `beds` (status transitions)

Update pattern: `WHERE id = ? AND version = ?` → increment version.

---

## Data Volume Estimates (Year 3)

| Entity | Rows | Avg Row Size |
|--------|------|--------------|
| Organizations | 10,000 | 2 KB |
| Properties | 50,000 | 5 KB |
| Beds | 2,000,000 | 500 B |
| Tenancies | 1,000,000 | 3 KB |
| Invoices | 12,000,000/yr | 1 KB |
| Audit logs | 100M/yr | 500 B → partition by month |

**Partitioning:** `audit_logs`, `notifications` by `createdAt` (monthly partitions).
