# Rentle — mobile

Flutter app (Android + iOS, one codebase) for Rentle's Pilot v1: owner/manager sets up
properties/rooms/beds, invites tenants, generates invoices, records payments, and manages
complaints. A small tenant-facing flow (accept invite, file complaints, upload documents)
is also included — see `docs/PROGRESS.md` in the repo root for the full picture.

## Before you run anything

You need the **Clerk publishable key** (safe to pass on the command line — unlike the
secret key, it's designed to be public): Clerk Dashboard → your project → **API Keys** →
copy the value starting `pk_test_...` (or `pk_live_...` in production).

It's passed via `--dart-define` and is **never** hardcoded or committed anywhere in this
repo (see `lib/core/config/env.dart`) — you'll need it for every command below.

The API server (`API_BASE_URL`) defaults to `https://rentle-gdys.onrender.com`, so you
don't need to pass it unless you're pointing at a different environment. Render's free
tier sleeps after 15 minutes idle — the first request after a while can take 30–60s to
wake it up; that's expected, not a bug.

## Running on a connected Android phone (USB debug)

1. On the phone: Settings → About phone → tap "Build number" 7 times to enable Developer
   options, then Settings → Developer options → enable **USB debugging**.
2. Plug the phone in, accept the "Allow USB debugging?" prompt on the phone.
3. Confirm it's detected: `flutter devices` should list it.
4. Run:
   ```
   flutter run --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...
   ```
   This installs a debug build and hot-reloads on save — the fastest loop for trying
   things out.

## Building an installable Android APK (sideload, no Play Store)

```
flutter build apk --release --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. Copy it to the phone (USB, email,
Drive — whatever's convenient) and open it there to install; you'll need to allow
"install from unknown sources" for whichever app you used to transfer it. This build is
signed with Flutter's debug key (see `android/app/build.gradle.kts`) — that's fine for
sideloading to your own device or a pilot user's, but isn't a Play Store–ready signature.

## Running on a connected iPhone (real device, not Simulator)

Real-device iOS runs need Xcode code signing — this part can't be scripted, it's a
one-time manual step per machine:

1. Open `ios/Runner.xcworkspace` in Xcode (not the `.xcodeproj`).
2. Select the `Runner` target → **Signing & Capabilities**.
3. Under **Team**, pick your Apple ID (sign in via Xcode → Settings → Accounts if it's
   not listed yet — a free personal Apple ID works, no paid developer account needed for
   running on your own device).
4. Plug in the iPhone, trust the computer if prompted.
5. On the iPhone: Settings → General → VPN & Device Management → trust the developer
   certificate the first time you install (iOS blocks unsigned/untrusted apps by default).
6. Back in the terminal:
   ```
   flutter run --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...
   ```
   or build+run directly from Xcode with the device selected as the run target.

The **Apple Developer Program ($99/yr)** is only needed for TestFlight/App Store
distribution to *other people's* iPhones — running on your own device via a free Apple ID
doesn't require it (see `docs/PROGRESS.md` decisions log, 2026-08-08).

## Everyday commands

```
flutter analyze   # static analysis — should report 0 issues
flutter test      # smoke test
flutter devices   # list connected devices/simulators
```
