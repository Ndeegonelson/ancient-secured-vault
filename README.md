# ANCIENT SECURED VAULT

ANCIENT SECURED VAULT is a Flutter Web and Android secure document vault backed by Firebase. It provides controlled access to free and protected PDF libraries, image-based protected reading, reader tools, subscriptions, admin review workflows, and mobile-friendly reading.

## Core Features

- Firebase email authentication
- Free access zone and protected main vault
- Admin command center for documents, users, devices, payments, and reader activity
- Firebase Storage PDF upload and delivery
- Protected PDF image reader to reduce text copying and selection
- Free and protected PDF zoom, pinch zoom, horizontal scroll, and vertical scroll
- Mobile PDF reader with portrait and landscape support
- Reader notes, highlights, bookmarks, and saved reading positions
- Searchable PDF index and search jump support
- Browser and native narration support with speed control
- Stripe subscription checkout and webhook activation
- Paystack subscription checkout and webhook activation
- Manual payment proof submission and admin approval or decline
- Subscription audit logs and admin-managed expiry support
- Device review and authorization tracking
- User registration profile fields: full name and searchable country selector with flags
- Web favicon and Android app icon branding

## Production URLs

- Web app: https://vault.ancientsociety.tech
- Firebase hosting fallback: https://ancient--docs.web.app
- Firebase project: `ancient--docs`

## Repository Structure

```text
lib/                  Flutter app source
lib/main.dart         Web entrypoint
lib/main_mobile.dart  Android WebView/mobile shell entrypoint
lib/services/         Firebase, access, subscription, reader, and narration services
lib/widgets/          Reusable reader and narration widgets
functions/            Firebase Cloud Functions for payments and scheduled tasks
test/                 Dart tests
functions/test/       Cloud Functions tests
android/              Android APK project
web/                  Web app icons, manifest, and hosting shell
firestore.rules       Firestore security rules
firebase.json         Firebase hosting and functions configuration
cors.json             Storage CORS configuration
```

## Required Local Tools

- Flutter SDK
- Firebase CLI
- Node.js for Firebase Functions
- Android Studio SDK/JBR for APK builds
- Git

## Local Web Build

Use local Dart cache folders to avoid Windows profile cache issues:

```powershell
cd C:\Users\Master-Ndeego\ancient_secure_docs
$env:APPDATA=(Join-Path (Get-Location) '.dart-appdata')
$env:LOCALAPPDATA=(Join-Path (Get-Location) '.dart-localappdata')
flutter build web --no-wasm-dry-run
```

## Deploy Web Hosting

```powershell
firebase deploy --only hosting --project ancient--docs
```

## Build Android Debug APK

```powershell
cd C:\Users\Master-Ndeego\ancient_secure_docs
$env:APPDATA=(Join-Path (Get-Location) '.dart-appdata')
$env:LOCALAPPDATA=(Join-Path (Get-Location) '.dart-localappdata')
$env:ANDROID_HOME='C:\Android-Studio'
$env:ANDROID_SDK_ROOT='C:\Android-Studio'
$env:JAVA_HOME='C:\Android-Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\emulator;$env:Path"
flutter build apk --debug -t lib\main_mobile.dart
```

APK output:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

Install on a connected Android device:

```powershell
adb devices
adb -s DEVICE_SERIAL install -r -d --no-streaming build\app\outputs\flutter-apk\app-debug.apk
```

## Firebase Functions

Important deployed functions include:

- `createStripeCheckoutSession`
- `createStripeBillingPortalSession`
- `stripeWebhook`
- `createPaystackCheckoutSession`
- `paystackWebhook`
- `expireAdminManagedSubscriptions`

Deploy selected functions:

```powershell
firebase deploy --only functions:createStripeCheckoutSession,functions:createPaystackCheckoutSession --project ancient--docs
```

Deploy rules:

```powershell
firebase deploy --only firestore:rules --project ancient--docs
```

## Secrets

Do not commit payment secrets or webhook secrets to GitHub. They are managed through Firebase Secret Manager.

Required secrets/config values include:

- `STRIPE_SECRET_KEY`
- `STRIPE_PREMIUM_PRICE_ID`
- `STRIPE_WEBHOOK_SECRET`
- `PAYSTACK_SECRET_KEY`
- `APP_BASE_URL`

The web and Android premium plan is **USD 120 per year**. Paystack's
amount and currency are enforced in the backend as `12000` USD subunits and
one calendar year of access. The Stripe Price referenced by
`STRIPE_PREMIUM_PRICE_ID` must be an active recurring USD 120 yearly Price;
checkout rejects any mismatched Price instead of charging the wrong amount.

Keep the Stripe Price ID and both payment-provider keys in test mode until the
production-payment migration is performed. Switching modes requires matching
live keys, a live USD 120 yearly Stripe Price, and live webhook secrets.

Example secret update:

```powershell
firebase functions:secrets:set APP_BASE_URL --project ancient--docs
```

## Verification Checklist

After major changes, verify:

- Web build completes
- Hosting deploy completes
- Android APK builds with `lib\main_mobile.dart`
- Registration creates user profile with name and country
- Free PDF opens
- Protected PDF opens
- Pinch zoom works on Android
- Vertical and horizontal PDF scrolling work
- Narration plays at normal speed
- Search result opens the matching page
- Notes, bookmarks, and reading position save correctly
- Stripe, Paystack, and manual payment flows remain blocked for already-active premium users

## GitHub Notes

Keep secrets, generated caches, and local device files out of commits.

Ignored local folders should include:

- `build/`
- `.dart_tool/`
- `.dart-appdata/`
- `.dart-localappdata/`
- `.firebase/`
- `node_modules/`
- `LocalLow/`
