# App Privacy Quick Checklist ✅

Быстрый чеклист для заполнения App Privacy в App Store Connect.

---

## 🎯 Что выбрать

### ✅ Contact Info
- [x] **Name**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **App Functionality**

- [x] **Email Address**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **App Functionality**

### ✅ Identifiers
- [x] **User ID**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **App Functionality, Analytics**

- [x] **Device ID**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **Analytics**

### ✅ Contact Info / Location from Google Sign-In SDK
- [x] **Phone Number**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **App Functionality**

- [x] **Coarse Location**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **App Functionality**

### ✅ Other Data from Google Sign-In SDK
- [x] **Other Data Types**
  - App Store Connect draft: configured
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **App Functionality, Analytics**

- [x] **Other Usage Data**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **Analytics**

### ✅ Usage Data
- [x] **Product Interaction**
  - Linked to user: YES (submitted product requests include the account user ID)
  - Used for tracking: NO
  - Purpose: **App Functionality**

### ✅ Diagnostics
- [x] **Other Diagnostic Data**
  - Linked to user: NO
  - Used for tracking: NO
  - Purpose: **Analytics**
  - Source: Firebase Authentication 12.18.0 bundled privacy manifest

---

## ❌ Что НЕ выбирать

- [ ] Precise Location
- [ ] Contacts
- [ ] Photos/Videos
- [ ] Health & Fitness
- [ ] Financial Info
- [ ] Browsing History
- [ ] Search History
- [ ] Advertising Data
- [ ] Crash Data
- [ ] Performance Data
- [ ] Purchase History — StoreKit entitlement is checked on device and is not sent to Pickly's servers
- [ ] Sensitive Info

---

## 📝 Third-Party Partners

**Do third parties have access?** → YES

**Partners:**
1. Firebase Authentication (optional account authentication)
2. Cloudflare (product catalog and account-linked requests)
3. Open Food Facts (product lookup)
4. Google Sign-In (optional authentication)

---

## ⚠️ Важно

- **Tracking:** NO (не использовать ATT)
- **Advertising:** NO
- **Analytics:** YES for the Google Sign-In SDK categories listed above and Firebase Authentication's unlinked Other Diagnostic Data; no standalone Firebase Analytics, crash-reporting, or advertising SDK is present
- **Current draft:** all 10 selected data types are configured; User ID includes App Functionality + Analytics. Keep Publish pending until archive verification.

---

## 🔗 Privacy Policy URL

```
https://funnymataleao.github.io/pickly/privacy.html
```

---

Полная инструкция: `Scripts/APP_PRIVACY_DETAILS_GUIDE.md`
