# 07 — API Documentation

**Base URL:** `https://api.rentle.com/api/v1`  
**Auth:** Clerk JWT Bearer token + `X-Organization-Id` header  
**Format:** JSON  
**Versioning:** URL path (`/v1/`)

---

## 1. Standard Response Envelope

### Success
```json
{
  "success": true,
  "data": { },
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 142,
    "hasMore": true
  }
}
```

### Error
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Bed capacity cannot be less than occupancy",
    "details": [{ "field": "sharingCapacity", "message": "..." }]
  }
}
```

### Error Codes
| Code | HTTP | Description |
|------|------|-------------|
| `UNAUTHORIZED` | 401 | Missing/invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `VALIDATION_ERROR` | 400 | Zod validation failed |
| `CONFLICT` | 409 | Optimistic lock / duplicate |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error (no leak) |

---

## 2. Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/webhook/clerk` | Clerk user/org sync (signed) |
| GET | `/auth/me` | Current user + memberships |
| GET | `/auth/sessions` | Active sessions |
| DELETE | `/auth/sessions/:id` | Revoke session |

**Headers (all protected routes):**
```
Authorization: Bearer <clerk_jwt>
X-Organization-Id: <org_cuid>
X-Property-Id: <property_cuid>  // optional scope
```

---

## 3. Organizations

| Method | Endpoint | Permission |
|--------|----------|------------|
| GET | `/organizations/:orgId` | `org:read` |
| PATCH | `/organizations/:orgId` | `org:write` |
| GET | `/organizations/:orgId/members` | `member:read` |
| POST | `/organizations/:orgId/members/invite` | `member:write` |
| PATCH | `/organizations/:orgId/members/:id` | `member:write` |
| DELETE | `/organizations/:orgId/members/:id` | `member:delete` |

---

## 4. Properties & Inventory

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/organizations/:orgId/properties` | List (paginated, filter) |
| POST | `/organizations/:orgId/properties` | Create property |
| GET | `/organizations/:orgId/properties/:propertyId` | Detail + stats |
| PATCH | `/organizations/:orgId/properties/:propertyId` | Update |
| DELETE | `/organizations/:orgId/properties/:propertyId` | Soft delete |
| GET | `.../buildings` | Building tree |
| POST | `.../rooms` | Create room |
| PATCH | `.../rooms/:roomId` | Update room |
| DELETE | `.../rooms/:roomId` | Delete (blocked if occupied) |
| GET | `.../beds` | Bed grid with status filter |
| PATCH | `.../beds/:bedId/status` | Transition bed state |
| GET | `.../availability` | Vacant beds calendar |

**Query params (list endpoints):**
- `page`, `limit` (max 100)
- `sort` (e.g. `createdAt:desc`)
- `filter[status]`, `filter[search]`
- `fields` (sparse fieldsets)

---

## 5. Tenants & Tenancies

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `.../tenancies` | Active tenants list |
| POST | `.../tenancies/invite` | Send joining link |
| GET | `.../tenancies/:id` | Detail + timeline |
| PATCH | `.../tenancies/:id` | Update rent, dates |
| POST | `.../tenancies/:id/transfer` | Bed transfer |
| POST | `.../tenancies/:id/notice` | Give notice |
| POST | `.../tenancies/:id/move-out` | Complete move-out |
| POST | `.../tenancies/:id/documents` | Upload (presigned URL flow) |
| GET | `.../tenancies/:id/documents` | List documents |

### Tenant App (`/tenant/*`)
| Method | Endpoint |
|--------|----------|
| GET | `/tenant/home` |
| GET | `/tenant/invoices` |
| POST | `/tenant/invoices/:id/pay` |
| GET | `/tenant/complaints` |
| POST | `/tenant/complaints` |
| GET | `/tenant/notices` |
| POST | `/tenant/visitors` |

---

## 6. CRM & Leads

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `.../leads` | List + kanban grouping |
| POST | `.../leads` | Create lead |
| GET | `.../leads/:id` | Detail + timeline |
| PATCH | `.../leads/:id` | Update stage, assign |
| POST | `.../leads/:id/notes` | Add note |
| POST | `.../leads/:id/follow-ups` | Schedule follow-up |
| POST | `.../leads/:id/convert` | Convert to tenancy |
| GET | `.../leads/analytics` | Funnel metrics |

---

## 7. Payments & Invoices

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `.../invoices` | List with status filter |
| POST | `.../invoices/generate` | Manual/cron trigger |
| GET | `.../invoices/:id` | Detail + line items |
| GET | `.../invoices/:id/pdf` | Signed PDF URL |
| POST | `.../payments` | Manual payment entry |
| POST | `.../payments/razorpay/order` | Create Razorpay order |
| POST | `/webhooks/razorpay` | Payment webhook (idempotent) |
| POST | `/webhooks/cashfree` | Cashfree webhook |
| GET | `.../ledger` | Ledger entries |
| GET | `.../reports/collection` | Collection report |

---

## 8. Operations

| Resource | Base Path |
|----------|-----------|
| Complaints | `.../complaints` |
| Notices | `.../notices` |
| Visitors | `.../visitors` |
| Food menus | `.../food-menus` |
| Staff | `.../staff` |
| Attendance | `.../attendance` |

---

## 9. Public API (Rate Limited)

| Method | Endpoint | Auth |
|--------|----------|------|
| GET | `/public/properties/:slug` | None |
| GET | `/public/properties/:slug/availability` | None |
| POST | `/public/properties/:slug/enquiry` | API key optional |
| POST | `/public/properties/:slug/book` | None |

Rate limit: 60 req/min per IP.

---

## 10. Super Admin

| Method | Endpoint |
|--------|----------|
| GET | `/admin/organizations` |
| PATCH | `/admin/organizations/:id/suspend` |
| POST | `/admin/impersonate/:userId` |
| GET | `/admin/analytics/mrr` |
| GET | `/admin/feature-flags` |
| PATCH | `/admin/feature-flags/:key` |

---

## 11. Webhooks (Outbound)

Organizations can register webhooks for:
- `tenancy.created`
- `payment.succeeded`
- `invoice.overdue`
- `complaint.created`

Payload signed with HMAC-SHA256.

---

## 12. OpenAPI / Swagger

Generated from NestJS decorators at:
`https://api.rentle.com/docs` (protected in staging; public in dev)

---

## 13. Idempotency

Mutating endpoints accept:
```
Idempotency-Key: <uuid>
```
Stored 24h in Redis. Required for payment creation.

---

## 14. Caching

| Endpoint | Cache |
|----------|-------|
| GET property detail | 60s CDN |
| GET dashboard stats | 30s Redis |
| GET public availability | 15s edge |

Invalidate on write via cache tags: `org:{id}`, `property:{id}`.
