# Demo account for App Review

Pickly does not require an account for its core Search, Scan, Product Result,
Saved, and History flows. Saved products, history, and preferences are local to
the device; signing in does not download seeded saved products or preferences.

## Recommended App Review setup

1. In App Store Connect, set **Sign-in required** to **No**.
2. In Review Notes, explain that reviewers can complete onboarding as a guest,
   search the catalog, enter a barcode manually, scan a barcode, save a product,
   and inspect product results without signing in.
3. If Apple asks for account-specific testing, create a temporary confirmed
   Firebase Authentication email user and store its unique password only in a
   password manager and App Store Connect. Never save the password in this
   repository.

Suggested Review Notes:

```text
An account is optional. Choose Continue without account during onboarding to
test the complete Search, Scan, Product Result, Saved, and History flows.
Saved products and preferences remain on the device. To test account creation,
open Profile > Sign in and use Apple, Google, or email.
```

## Optional account smoke test

1. Open **Profile > Sign in**.
2. Create or sign in to a confirmed test account.
3. Verify sign-out returns to the signed-out state.
4. Verify **Delete account** removes the server account and clears local saved
   products and preferences.
5. Verify **Forgot password?** sends a Firebase reset email. Complete the
   reset in the secure Firebase-hosted page, then return to Pickly and sign in
   with the new password.

Do not seed `user_saved_products` or `user_preferences` for review: the current
app intentionally stores those values locally and does not read those tables.
