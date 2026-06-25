# 12 — Sprint Planning (Revised)

**Sprint length:** 2 weeks  
**Focus:** Strengthen Firebase MVP — no infrastructure rewrite  

---

## Sprint 1 — Complete ✓

MVP foundation: OTP pipeline, rent `/generate` fix, API envelopes, logging, services layer, audit foundation, tests.

---

## Sprint 2 — Complete ✓

| Priority | Story | Status |
|----------|-------|--------|
| 1 | MSG91 SMS adapter + OTP dispatch in production mode | Done |
| 2 | UPI deep link payments (owner UPI from PG record) | Done |
| 3 | Payment gateway abstraction (Razorpay stub for later) | Done |
| 4 | Owner custom charges (fines, utilities, etc.) | Done |
| 5 | Document upload URL API (Firebase Storage) | Done |
| 6 | Audit logging on room/tenant/charge/payment mutations | Done |
| 7 | Mobile: add charge screen + tenant UPI pay flow | Done |
| 8 | Unit tests (UPI link builder) | Done |

### New API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/owner/charges` | Owner imposes fine/custom charge on tenant |
| GET | `/api/owner/charges` | List non-rent charges |
| POST | `/api/tenant/payments/pay` | Get UPI deep link for a record |
| POST | `/api/documents/upload-url` | Signed upload URL (owner/tenant) |

### Payment Flow

1. Owner sets UPI ID in Settings
2. Rent generation / custom charge creates record with `paymentDeepLink`
3. Tenant taps Pay → opens UPI app via deep link
4. Tenant confirms → `mark-paid` records payment

### Production OTP

Set `AUTH_MODE=production` + configure `MSG91_AUTH_KEY` and `MSG91_OTP_TEMPLATE_ID`.

---

## Sprint 3 (Planned)

| Story | Points |
|-------|--------|
| Owner manual payment confirmation (UTR entry) | 5 |
| Tenant document upload UI | 8 |
| WhatsApp rent reminders (adapter) | 5 |
| Owner charges list screen | 5 |
| Firestore emulator integration tests | 8 |

---

## Architectural Principle

Business logic uses **services + interfaces**. UPI today, Razorpay tomorrow — swap `getPaymentGateway()` only.
