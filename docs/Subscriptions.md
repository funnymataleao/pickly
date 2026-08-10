# Pickly Plus

## Product model

Pickly keeps the core grocery flow free: barcode scanning, manual search, the
score and explanation, basic preferences, and one available alternative.

Pickly Plus unlocks the complete alternative set and side-by-side comparison.
The paywall is opened only after a user asks to see more alternatives. It never
blocks the first result or basic product clarity.

## StoreKit products

Use one auto-renewable subscription group named **Pickly Plus**:

| Product ID | Name | Price hypothesis | Period |
| --- | --- | --- | --- |
| `com.pickly.plus.monthly` | Pickly Plus Monthly | €4.99 | 1 month |
| `com.pickly.plus.annual` | Pickly Plus Annual | €29.99 | 1 year |

The local StoreKit configuration is [`Config/PicklySubscriptions.storekit`](../Config/PicklySubscriptions.storekit). It is for Xcode development only; App Store Connect products must be created with the same IDs before a TestFlight or App Store build can sell subscriptions.

## App Store Connect checklist

1. Create the **Pickly Plus** subscription group.
2. Add the monthly and annual products with the IDs above.
3. Add English localizations and the approved prices.
4. Add the app's Privacy Policy URL and Apple's Standard EULA in the subscription metadata.
5. Complete Paid Apps Agreement, banking, and tax information.
6. Test purchase, restore, renewal, cancellation, expiration, and billing retry in Sandbox/TestFlight.

Do not put an App Store Connect API key or a private signing key in the app. A
server-side entitlement table and App Store Server Notifications should be
added only when Pickly Plus features require account sync or protected backend
operations.
