# 03 — User Flows

---

## Flow 1: Organization Onboarding

```mermaid
flowchart TD
    A[Visit rentle.com] --> B[Sign up with Clerk]
    B --> C[Create Organization]
    C --> D[Choose subscription tier]
    D --> E[Add first Property]
    E --> F[Configure buildings/floors/rooms/beds]
    F --> G[Invite Manager staff]
    G --> H[Owner Dashboard live]
```

**Steps:**
1. Owner signs up → Clerk creates user + org
2. Webhook syncs `Organization` record in PostgreSQL
3. Setup wizard: property name, address, rent cycle, UPI/bank details
4. Bed inventory import (CSV or manual)
5. Optional: connect Razorpay merchant account

---

## Flow 2: Lead → Tenant Conversion

```mermaid
flowchart TD
    A[Lead captured] --> B{Source?}
    B -->|Website| C[Booking form]
    B -->|Walk-in| D[Receptionist manual entry]
    B -->|WhatsApp| E[CRM import]
    C --> F[Assign to sales exec]
    D --> F
    E --> F
    F --> G[Schedule visit]
    G --> H[Visit completed - notes]
    H --> I{Interested?}
    I -->|No| J[Lost - reason]
    I -->|Yes| K[Token payment]
    K --> L[Reserve bed]
    L --> M[Send joining link/QR]
    M --> N[Tenant completes onboarding form]
    N --> O[Upload documents]
    O --> P[Manager approves]
    P --> Q[Generate agreement]
    Q --> R[E-sign]
    R --> S[Bed status = Occupied]
    S --> T[First rent invoice generated]
```

---

## Flow 3: Monthly Rent Collection

```mermaid
flowchart TD
    A[Cron: 1st of month] --> B[Generate invoices per active tenancy]
    B --> C[Apply custom charges + late rules]
    C --> D[Notify tenant push/WhatsApp/email]
    D --> E{Tenant pays}
    E -->|Razorpay| F[Webhook confirms payment]
    E -->|Manual UPI| G[Manager marks paid + UTR]
    F --> H[Update ledger]
    G --> H
    H --> I[Receipt PDF generated]
    I --> J[Owner collection report updated]
    E -->|Unpaid after grace| K[Late fine applied]
    K --> D
```

---

## Flow 4: Tenant Complaint Resolution

```mermaid
flowchart TD
    A[Tenant submits complaint] --> B[Auto-assign category + priority]
    B --> C[Notify assigned staff]
    C --> D[Staff updates status]
    D --> E{Resolved?}
    E -->|No| F[Escalate to manager]
    F --> D
    E -->|Yes| G[Tenant confirms / auto-close 48h]
    G --> H[Analytics updated]
```

---

## Flow 5: Visitor Entry (Tenant-Approved)

```mermaid
flowchart TD
    A[Visitor arrives] --> B[Receptionist creates entry request]
    B --> C[Push to tenant for approval]
    C --> D{Tenant approves?}
    D -->|Yes| E[QR pass generated]
    E --> F[Scan at entry]
    F --> G[Scan at exit]
    D -->|No| H[Denied - log reason]
    D -->|Timeout 15min| I[Manager override option]
```

---

## Flow 6: Tenant Move-Out

```mermaid
flowchart TD
    A[Tenant gives notice] --> B[Notice period countdown]
    B --> C[Final utility charges calculated]
    C --> D[Deposit settlement invoice]
    D --> E{Deductions?}
    E -->|Yes| F[Itemized deduction + approval]
    E -->|No| G[Refund initiated]
    F --> G
    G --> H[Bed released to Vacant]
    H --> I[Tenant archived]
```

---

## Flow 7: Super Admin Support

```mermaid
flowchart TD
    A[Org submits support ticket] --> B[Super Admin reviews]
    B --> C{Need impersonation?}
    C -->|Yes| D[Audited impersonation session]
    D --> E[Debug / fix config]
    C -->|No| F[Respond via ticket]
    E --> G[End impersonation - log]
    F --> H[Close ticket]
    G --> H
```

---

## Flow 8: White-Label Property Website

```mermaid
flowchart TD
    A[Prospect visits property.rentle.site or custom domain] --> B[Browse gallery + pricing]
    B --> C[Check bed availability]
    C --> D[Submit enquiry / Reserve bed]
    D --> E[Lead created in CRM]
    E --> F[WhatsApp chat widget optional]
```

---

## Edge Cases (Must Handle)

| Flow | Edge Case | Behavior |
|------|-----------|----------|
| Lead conversion | Duplicate phone in CRM | Merge suggestion, block duplicate active lead |
| Rent | Partial payment | Allocate to oldest invoice; show balance |
| Bed transfer | Mid-month transfer | Prorate rent; close old tenancy line item |
| Delete room | Active tenant | Block delete (current MVP behavior preserved) |
| Payment webhook | Duplicate webhook | Idempotency key on `Payment.externalId` |
| Invite | Expired joining link | Regenerate; audit old invite |
