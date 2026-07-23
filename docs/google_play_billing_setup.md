# Google Play Billing setup

Ancient Secured Vault uses Google Play Billing for digital premium access in
the Play-distributed Android app. The web app continues to use Stripe and
Paystack, while iOS uses the App Store purchase flow.

## Canonical product

- Android package: `tech.ancientsociety.vault`
- Subscription product ID: `tech.ancientsociety.vault.premium.yearly`
- Suggested base plan ID: `annual-auto-renewing`
- Billing period: yearly, auto-renewing
- Reference price: USD 120 per year

The product ID is embedded in both the Android purchase controller and the
server verifier. Do not create the Play product under a different ID.

## 1. Deploy purchase verification

The HTTPS function verifies every purchase with the Google Play Developer API
before granting premium access. It also acknowledges verified purchases.

```powershell
firebase.cmd deploy --only "functions:verifyGooglePlayPurchase" --project ancient--docs
```

Enable the Google Play Android Developer API for project `ancient--docs`. In
Play Console, link the runtime service account under **Setup > API access** and
grant only the permissions needed to view subscriptions and manage orders.
Without this link, checkout may complete but the app cannot verify or activate
the subscription.

## 2. Upload a billing-enabled internal-test bundle

Build the Android wrapper explicitly. Do not use Flutter's default web entry
point for the Android bundle.

```powershell
flutter build appbundle --release --target lib/main_mobile.dart --build-name 1.0.2 --build-number 8
```

The version code must be greater than every Android artifact already uploaded
to Play. If `8` has already been used, choose the next unused number.

Upload `build/app/outputs/bundle/release/app-release.aab` to **Test and release
> Testing > Internal testing**. The merged bundle must contain the permission
`com.android.vending.BILLING`.

## 3. Create the Play subscription

After Play processes the billing-enabled bundle:

1. Open **Monetize with Play > Products > Subscriptions**.
2. Create product `tech.ancientsociety.vault.premium.yearly`.
3. Add an auto-renewing yearly base plan named `annual-auto-renewing`.
4. Set the reference price to USD 120 per year and review Play's localized
   prices, including Ghana.
5. Activate the base plan and subscription.

The Android UI loads the localized price directly from Google Play. It must not
hard-code or independently convert the Play charge.

## 4. Configure testing

1. Add the Gmail account under the internal testing track's tester list.
2. Add the same account under **Settings > License testing**.
3. Publish the internal release and install it from the Play opt-in link.
4. Sign into the same Ancient Secured Vault account used for the test.
5. Confirm checkout shows the yearly product, purchase activation, expiry date,
   restore purchases, and Google Play subscription management.

An APK installed by ADB is useful for UI checks but is not a reliable billing
test. Product discovery and test payment must be verified using the Play-installed
internal-test build.

## Production gate

Before production, configure Google Play Real-time Developer Notifications so
renewals, refunds, revocations, grace periods, and account holds are reconciled
server-side. Keep server verification, purchase-token uniqueness, Firebase-user
binding, and acknowledgement enabled.
