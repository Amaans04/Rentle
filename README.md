# Rentle

**PG Management, Simplified** — B2B SaaS platform for PG accommodation management in India.

## Status

**Phase 1 (MVP):** Active — Firebase + Next.js + Flutter  
**Enterprise architecture:** Documented in `docs/` — build in parallel after MVP stability  
**Sprint 1:** MVP foundation hardening (see [docs/12-sprint-planning.md](./docs/12-sprint-planning.md))

```
rentle/
├── server/     # Next.js 14 API + web dashboard
├── mobile/     # Flutter mobile app (role-based)
└── README.md
```

## Prerequisites

- Node.js 18+
- Flutter 3.12+
- Firebase project with Firestore + Auth enabled

## Environment Setup

### Server (`server/.env`)

Copy `server/.env.example` to `server/.env` and fill in:

```bash
cp server/.env.example server/.env
```

| Variable | Description |
|----------|-------------|
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Service account email |
| `FIREBASE_PRIVATE_KEY` | Service account private key |
| `JWT_SECRET` | Access token secret (`openssl rand -base64 64`) |
| `JWT_REFRESH_SECRET` | Refresh token secret (`openssl rand -base64 64`) |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins |
| `NEXT_PUBLIC_APP_URL` | Public app URL |
| `AUTH_MODE` | `development` (OTP bypass) or `production` (strict OTP) |
| `OTP_BYPASS` | Optional explicit override (`true`/`false`) |
| `OTP_EXPIRY_MINUTES` | OTP session TTL (default 10) |
| `OTP_MAX_ATTEMPTS` | Max verify attempts per session (default 5) |
| `FIREBASE_STORAGE_BUCKET` | Optional — defaults to `{projectId}.appspot.com` |

**Never commit `.env` files.** All secrets live in environment variables only.

### Mobile (`mobile/.env`)

Copy `mobile/.env.example` to `mobile/.env` and fill in:

```bash
cp mobile/.env.example mobile/.env
```

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Your Next.js server URL |
| `FIREBASE_API_KEY` | From Firebase Console → Project Settings → Your app |
| `FIREBASE_AUTH_DOMAIN` | e.g. `rentle-5b171.firebaseapp.com` |
| `FIREBASE_PROJECT_ID` | e.g. `rentle-5b171` |
| `FIREBASE_MESSAGING_SENDER_ID` | From Firebase app config |
| `FIREBASE_APP_ID` | From Firebase app config |

**Never commit `mobile/.env` to git.** Just run `flutter run` — no terminal flags needed.

## Run the Server

```bash
cd server
npm install
npm run dev
```

Server runs at [http://localhost:3000](http://localhost:3000).

- Web dashboard: `/login`
- API routes: `/api/*`

## Run the Mobile App

```bash
cd mobile
flutter pub get
flutter run
```

Use `http://10.0.2.2:3000` as `API_BASE_URL` in `mobile/.env` for Android emulator.

## Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Phone + Google sign-in)
3. Create **Firestore** database (production mode)
4. Generate a **service account key** for the server (Project Settings → Service Accounts)
5. Add Android/iOS apps for the Flutter client and download config files

### Firestore Collections

Collections are created automatically by the API on first write:

- `users`, `pgs`, `rooms`, `tenants`, `staff`
- `rentRecords`, `complaints`, `notices`, `invites`
- `refreshTokens`, `otpRateLimit`, `otpSessions`, `auditLogs`

**Critical rule:** Every PG-scoped document has a `pgId` field. All queries filter by `pgId` from the JWT — never from the request body.

### Recommended Firestore Indexes

Create composite indexes for:
- `rentRecords`: `pgId` + `month` + `year`
- `rentRecords`: `pgId` + `tenantId` + `month` + `year`
- `complaints`: `pgId` + `createdAt`
- `invites`: `phone` + `status`

## Security

- JWT access tokens: 15 min expiry
- Refresh tokens: 7 days, stored in `refreshTokens/` collection, revocable
- Web auth: httpOnly secure cookies
- Mobile auth: Bearer token in `flutter_secure_storage`
- OTP rate limit: 3 requests per phone per 10 minutes
- Role-based access on every protected route
- Input validation and phone sanitization on all endpoints
- CORS restricted to `ALLOWED_ORIGINS`

## Test Mode

In `AUTH_MODE=development` (default), OTP is logged to the server console and **any 6-digit code is accepted** at verify. The full OTP pipeline (storage, expiry, rate limits, attempts) still runs.

For strict OTP matching: `AUTH_MODE=production` or `OTP_BYPASS=false`.

## Assumptions

- Indian phone numbers (10 digits, +91 prefix)
- Rent due date: 1st–28th of month
- UPI deep links for payments (no payment gateway SDK)
- Single invite per phone per PG at a time
- Owner creates PG via setup flow; tenants/managers join via invite

## Known Limitations (Phase 1)

- No real SMS OTP (console log only)
- No push notifications
- No document upload (Aadhaar/PAN placeholders in UI)
- No automated rent record generation (manual trigger)
- Payment confirmation is self-reported (no gateway webhook)
- No multi-PG support per owner
- Manager web access limited to dashboard, tenants, complaints, notices

## Phase 2 Roadmap

- Real SMS OTP via Firebase Auth or MSG91
- Razorpay/Cashfree payment gateway integration
- Push notifications (FCM)
- Document upload & verification
- Automated monthly rent record cron
- Multi-property support for owners
- Analytics & reporting dashboard
- Tenant move-out workflow with deposit settlement
- WhatsApp Business API for invites
- Firestore security rules (client-side reads)
