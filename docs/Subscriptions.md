# Pickly Plus

## Product model

Pickly keeps the core grocery flow free: barcode scanning, manual search, the
score and explanation, and basic preferences.

Pickly Plus unlocks the complete Better Choices set and side-by-side comparison
with a selected alternative. It never blocks the first result or basic product
clarity.

## StoreKit products

Use one auto-renewable subscription group named **Pickly Plus**:

| Product ID | Name | Price hypothesis | Period |
| --- | --- | --- | --- |
| `com.pickly.plus.monthly` | Pickly Plus Monthly | €4.99 | 1 month |
| `com.pickly.plus.annual` | Pickly Plus Annual | €29.99 | 1 year |

The local StoreKit configuration is [`Config/PicklySubscriptions.storekit`](../Config/PicklySubscriptions.storekit). It is for Xcode development only; App Store Connect is the source of truth for production availability and prices.

Current App Store Connect state on August 28, 2026:

- Subscription group **Pickly Plus** exists (`22285904`).
- Monthly product exists (`com.pickly.plus.monthly`, Apple ID `6797899031`, €4.99) and is Preparing for Submission.
- Annual product exists (`com.pickly.plus.annual`, Apple ID `6797907858`, €29.99) and is Preparing for Submission.

## App Store Connect checklist

1. Complete the monthly and annual product metadata and move both products to Ready to Submit.
2. Verify English localizations and the approved prices.
3. Add the app's Privacy Policy URL and Apple's Standard EULA in the subscription metadata.
4. Have the Account Holder accept the current Apple Developer Program License Agreement.
5. Verify agreements, banking, and tax status in App Store Connect.
6. Add both subscriptions to the same first Review Submission as the app build.
7. Test purchase, restore, renewal, cancellation, expiration, and billing retry in Sandbox/TestFlight.

Do not put an App Store Connect API key or a private signing key in the app. A
server-side entitlement table and App Store Server Notifications should be
added only when Pickly Plus features require account sync or protected backend
operations.
