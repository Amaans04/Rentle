# 09 — UI Wireframes

> Visual language: Stripe clarity + Linear density + Notion whitespace.  
> Component library: shadcn/ui + Tailwind + Framer Motion.

---

## Design Tokens

| Token | Value |
|-------|-------|
| Primary | `#2563EB` (Trust Blue) |
| Success | `#0D9488` (Teal) |
| Warning | `#F59E0B` (Amber) |
| Danger | `#EF4444` (Coral) |
| Surface | `#FAFAFA` / `#0A0A0A` (dark) |
| Radius | `12px` cards, `8px` inputs |
| Font | Inter (UI), optional display |

---

## 1. Owner Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│ [Logo] Acme PG ▾    🔍 Search... ⌘K    [Property ▾]  🔔  👤    │
├──────────┬──────────────────────────────────────────────────────┤
│ Dashboard│  Good morning, Rajesh                    Jun 2025 ▾  │
│ Properties│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│ Tenants  │ │Occupancy│ │Collection│ │ Pending │ │  Leads  │  │
│ Leads    │ │  87%    │ │ ₹4.2L   │ │  ₹32K   │ │   12    │  │
│ Payments │ └─────────┘ └─────────┘ └─────────┘ └─────────┘  │
│ Reports  │                                                      │
│ ...      │  Revenue (chart)          Occupancy heatmap          │
│          │  ┌──────────────────┐    ┌──────────────────┐       │
│          │  │    ▄▄▄▄▄▄▄       │    │  B1 B2 B3 B4     │       │
│          │  └──────────────────┘    └──────────────────┘       │
│          │                                                      │
│          │  Recent Activity                    Quick Actions     │
│          │  • Kavya paid ₹8,000               [+ Add Tenant]   │
│          │  • Room 204 vacant                   [+ Add Lead]     │
│          │  • Complaint #142 resolved           [Generate Rent] │
└──────────┴──────────────────────────────────────────────────────┘
```

**Components:** KPI cards (skeleton on load), Recharts area chart, activity feed, command palette overlay.

---

## 2. Rooms & Beds Grid

```
┌─────────────────────────────────────────────────────────────────┐
│ Rooms — Sunshine PG          [Floor ▾] [Status ▾]  [+ Add Room] │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │ Room 101 │  │ Room 102 │  │ Room 103 │  │ Room 104 │        │
│  │ ● Vacant │  │ ◐ Partial│  │ ● Full   │  │ ○ Maint. │        │
│  │ [A][B]   │  │ [A*][B ] │  │ [A*][B*] │  │ [A ][B ] │        │
│  │ ₹8,000   │  │ ₹7,500   │  │ ₹8,000   │  │ —        │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

**Interaction:** Click room → slide-over drawer with beds, tenants, actions (edit, add tenant, delete).

---

## 3. Lead CRM Kanban

```
┌─────────────────────────────────────────────────────────────────┐
│ Leads    [Kanban | List]    🔍 Filter    [+ New Lead]            │
├─────────────────────────────────────────────────────────────────┤
│ NEW (5)    │ CONTACTED │ VISIT     │ TOKEN PAID │ CONVERTED    │
│ ┌────────┐ │ ┌────────┐│ ┌────────┐│ ┌────────┐ │              │
│ │ Rahul  │ │ │ Priya  ││ │ Amit   ││ │ Sneha  │ │              │
│ │ 98xxx  │ │ │ WA     ││ │ Visit  ││ │ ₹2000  │ │              │
│ │ Website│ │ │ Tomorrow││ │ Fri 3pm││ │        │ │              │
│ └────────┘ │ └────────┘│ └────────┘│ └────────┘ │              │
└─────────────────────────────────────────────────────────────────┘
```

**Drag-drop** between columns with optimistic update + audit log.

---

## 4. Tenant Detail (Drawer)

```
┌──────────────────────────────────────┐
│ Kavya Sharma                    [×]  │
│ Room 102 · Bed A · Active            │
├──────────────────────────────────────┤
│ [Overview][Payments][Docs][Timeline] │
├──────────────────────────────────────┤
│ Rent: ₹8,000/mo    Due: 5th          │
│ Deposit: ₹16,000   Move-in: Jan 2025 │
│                                      │
│ [Collect Payment] [Give Notice]      │
│ [Transfer Bed]    [View Agreement]   │
└──────────────────────────────────────┘
```

---

## 5. Invoice & Payment Flow

```
Tenant App — Pay Rent
┌─────────────────────────┐
│  June 2025 Rent         │
│  ─────────────────      │
│  Rent          ₹8,000   │
│  Electricity     ₹450   │
│  ─────────────────      │
│  Total         ₹8,450   │
│                         │
│  [Pay with UPI]         │
│  [Pay with Card]        │
│  [View past invoices]   │
└─────────────────────────┘
```

---

## 6. Property Public Website

```
┌─────────────────────────────────────────────────────────────────┐
│  [Logo] Sunshine PG          [Book Now]  [WhatsApp]  [Call]     │
├─────────────────────────────────────────────────────────────────┤
│         HERO: Premium PG near Koramangala                        │
│         [Gallery carousel]                                       │
├─────────────────────────────────────────────────────────────────┤
│  Amenities    │  Rooms & Pricing    │  Location (Map)          │
│  WiFi AC Food │  Single ₹8K  [Book]  │  Google Maps embed       │
├─────────────────────────────────────────────────────────────────┤
│  Reviews · FAQ · Footer                                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Super Admin

```
┌─────────────────────────────────────────────────────────────────┐
│ Rentle Admin     MRR: ₹12.4L ↑8%    Orgs: 342    Churn: 2.1%   │
├──────────┬──────────────────────────────────────────────────────┤
│ Orgs     │  Search organizations...                               │
│ Billing  │  ┌────────────────────────────────────────────────┐  │
│ Support  │  │ Acme PG    Growth   Active   120 beds  [···]  │  │
│ Flags    │  │ Beta Hostel Starter Trial  45 beds   [···]  │  │
│ Logs     │  └────────────────────────────────────────────────┘  │
└──────────┴──────────────────────────────────────────────────────┘
```

---

## 8. Global UX Patterns

| Pattern | Implementation |
|---------|----------------|
| Loading | Skeleton screens (not spinners) |
| Empty state | Illustration + CTA |
| Errors | Toast + inline field errors |
| Confirm destructive | Alert dialog with typed confirm |
| Tables | TanStack Table + virtual scroll >100 rows |
| Forms | React Hook Form + Zod |
| Motion | Page transitions 200ms ease-out |
| Dark mode | `next-themes` class strategy |
| Mobile | Responsive; owner app mobile-web PWA Phase 2 |

---

## 9. Command Palette (⌘K)

```
┌─────────────────────────────────────┐
│ 🔍  Search tenants, rooms, leads... │
├─────────────────────────────────────┤
│ Recent                              │
│   Kavya Sharma — Tenant             │
│   Room 102 — Property               │
│ Actions                             │
│   + Add tenant                      │
│   + Create lead                     │
│   Go to Payments                    │
└─────────────────────────────────────┘
```
