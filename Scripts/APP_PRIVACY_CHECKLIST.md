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
  - Purpose: **App Functionality**

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

- [ ] Location
- [ ] Contacts
- [ ] Photos/Videos
- [ ] Health & Fitness
- [ ] Financial Info
- [ ] Browsing History
- [ ] Search History
- [ ] Device ID
- [ ] Advertising Data
- [ ] Diagnostics
- [ ] Other Data
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
- **Analytics:** NO

---

## 🔗 Privacy Policy URL

```
https://funnymataleao.github.io/pickly/privacy.html
```

---

Полная инструкция: `Scripts/APP_PRIVACY_DETAILS_GUIDE.md`
