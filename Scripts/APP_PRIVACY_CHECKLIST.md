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

### ✅ Purchases
- [x] **Purchase History**
  - Linked to user: YES
  - Used for tracking: NO
  - Purpose: **App Functionality**

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
- [ ] Diagnostics
- [ ] Sensitive Info

---

## 📝 Third-Party Partners

**Do third parties have access?** → YES

**Partners:**
1. Supabase (Backend, Auth)
2. Open Food Facts (Product lookup)
3. Google Sign-In (Auth)

---

## ⚠️ Важно

- **Tracking:** NO (не использовать ATT)
- **Advertising:** NO
- **Analytics:** YES only for Google Sign-In SDK categories listed above; no standalone analytics or advertising SDK is present

---

## 🔗 Privacy Policy URL

```
https://funnymataleao.github.io/pickly/privacy.html
```

---

Полная инструкция: `Scripts/APP_PRIVACY_DETAILS_GUIDE.md`
