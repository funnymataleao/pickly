# 🚀 Pickly - Готовность к App Store

Финальный чеклист перед отправкой в App Review.

---

## ✅ Подготовлено к финальной проверке

### 1. Privacy Policy ⚠️
**URL:** https://funnymataleao.github.io/pickly/privacy.html

**Статус:** локальная policy обновлена под текущий data flow, но публичная GitHub Pages-версия ещё должна быть опубликована и повторно проверена.

**Что добавить в App Store Connect:**
- App Information → Privacy Policy URL → вставь URL выше
- Проверь что ссылка открывается в браузере

---

### 2. Guest / Review access ✅
Core flow доступен без аккаунта. Если для дополнительной проверки будет создан demo account, передавай credentials только через App Store Connect App Review Information. Не храни пароль в репозитории или release notes.

**Что проверить перед отправкой:**
- Core flow работает без аккаунта.
- Если нужен аккаунт для проверки, credentials передаются только через App Store Connect.

**Что добавить в App Store Connect:**
- App Review Information → Sign-in Required: NO
- Notes: "Account access is optional. Saved products and preferences stay on this device. Reviewers can use barcode scanning, manual barcode entry, and product search without signing in."

---

### 3. App Privacy Details ⏳
**Статус:** Нужно заполнить вручную в App Store Connect

**Инструкции:**
- Полная: `Scripts/APP_PRIVACY_DETAILS_GUIDE.md`
- Краткая: `Scripts/APP_PRIVACY_CHECKLIST.md`

**Быстрый summary:**
- Name (Linked, App Functionality, No tracking; only when supplied by an identity provider)
- Email Address (Linked, App Functionality, No tracking)
- User ID (Linked, App Functionality, No tracking)
- Product Interaction (Linked for submitted product requests, App Functionality, No tracking)
- Purchases (Linked, App Functionality, No tracking)
- Third parties: Supabase, Open Food Facts, Google Sign-In

---

## 📋 Финальный Pre-Submission Checklist

### В App Store Connect:

- [ ] **App Information**
  - [ ] Privacy Policy URL добавлен
  - [ ] Category выбрана (рекомендуется Food & Drink)
  - [ ] Age Rating настроен
  - [ ] Copyright заполнен

- [ ] **App Privacy**
  - [ ] Email Address настроен
  - [ ] Name настроен
  - [ ] User ID настроен
  - [ ] Product Interaction настроен
  - [ ] Purchases настроен
  - [ ] Third parties указаны (Supabase, Open Food Facts, Google)
  - [ ] Published

- [ ] **App Review Information**
  - [ ] Sign-in Required: NO
  - [ ] If account testing is useful, provide credentials only in App Review Information
  - [ ] Notes добавлены
  - [ ] Contact info заполнен (твой email/телефон)

- [ ] **Pricing and Availability**
  - [ ] Territories выбраны
  - [ ] Price: Free (основная функциональность)

- [ ] **In-App Purchases** (обязательно, потому что paywall доступен в приложении)
  - [ ] Pickly Plus Monthly создан и имеет статус Ready to Submit
  - [ ] Pickly Plus Annual создан и имеет статус Ready to Submit
  - [ ] Оба продукта добавлены в ту же Review Submission, что и первый build с подписками

### В Xcode:

- [ ] **Build собран** без ошибок (Release configuration)
- [ ] **Bundle ID:** com.pickly.app.Pickly (проверь совпадает с App Store Connect)
- [ ] **Version:** 1.0
- [ ] **Build number:** 1
- [ ] **Sign in with Apple** работает на реальном устройстве
- [ ] **Google Sign-In** работает (если настроен)
- [ ] **StoreKit Configuration** добавлен в проект (PicklySubscriptions.storekit)
- [ ] **Supported devices:** только iPhone
- [ ] **Archive создан** и загружен в App Store Connect через Xcode Organizer

### Функциональные тесты:

- [ ] **Camera permission** запрашивается корректно
- [ ] **Barcode scanning** работает
- [ ] **Search** работает без аккаунта
- [ ] **Sign in with Apple** работает
- [ ] **Google Sign-In** работает (если настроен)
- [ ] **Email sign-in** работает
- [ ] **Account deletion** удаляет данные и отзывает provider grants на сервере
- [ ] **Saved products** сохраняются локально и переживают перезапуск
- [ ] **Preferences** сохраняются
- [ ] **Subscription UI** отображается (даже если продукты недоступны)

---

## 🎯 Следующие шаги

### 1. Заполни App Privacy Details (10 минут)
Открой `Scripts/APP_PRIVACY_DETAILS_GUIDE.md` и следуй инструкциям.

### 2. Создай Archive и загрузи в App Store Connect
```bash
# В Xcode:
1. Product → Archive
2. Window → Organizer
3. Distribute App → App Store Connect
4. Upload
5. Подожди 5-10 минут пока build обработается
```

### 3. Создай новую версию в App Store Connect
1. App Store → (плюс) iOS App → 1.0
2. Добавь iPhone-скриншоты для размеров, которые App Store Connect требует у текущей версии
3. Заполни App Description
4. Выбери Build
5. Submit for Review

---

## 📸 Скриншоты (нужны для App Store)

**Минимально нужны:**
- Только iPhone-наборы, которые показывает App Store Connect для текущей версии.
- Не растягивай и не ресайзь один скриншот под другое соотношение сторон.

**Рекомендуемые скриншоты:**
1. Onboarding / Home screen с поиском
2. Scan barcode (камера в действии)
3. Product Result (с verdict и score)
4. Alternatives (список лучших вариантов)
5. Saved products

**Инструменты:**
- Xcode Simulator → Cmd+S для скриншота
- Figma/Sketch для добавления текста/обрамления
- Или просто чистые скриншоты из симулятора

---

## 📝 App Description (пример)

**App Name:** Pickly

**Subtitle (30 chars):** Calm grocery clarity

**Promotional Text (170 chars):**
Scan product barcodes and get clear, calm nutrition guidance. Pickly shows you the score, explains why, and suggests better alternatives — all without panic or pressure.

**Description:**
```
Pickly helps you make better grocery choices quickly and calmly.

Scan a product barcode or search the catalog to see:
• Clear verdict: Great, Good, Okay, or Not great
• Plain-language explanation of the score
• What to watch (sugar, sodium, saturated fat, additives)
• Better alternatives when available
• Personalized notes based on your preferences

No panic. No shame. Just calm, clear guidance.

Features:
• Barcode scanner
• Product search
• Explainable scoring
• Better alternatives
• Save products for later
• Set dietary preferences
• Optional account sign-in

Pickly focuses on grocery and supermarket food products. Pickly uses its verified catalog and Open Food Facts for product data.

Privacy-first:
• Camera used only for barcode scanning
• Saved products stay on your device
• Optional account for account access
• No advertising identifiers
• No location tracking
```

**Keywords (100 chars):**
```
grocery,scanner,nutrition,barcode,food,healthy,products,shopping,diet,alternatives
```

**Support URL:**
```
https://github.com/funnymataleao/pickly
```

**Marketing URL:**
```
https://funnymataleao.github.io/pickly/
```

---

## ⏱️ Timeline

**После Submit for Review:**
- In Review: 24-48 часов
- Review время: 1-3 дня
- Возможные результаты:
  - ✅ Approved → Live в App Store через несколько часов
  - ⚠️ Metadata Rejected → исправь description/screenshots, resubmit
  - 🔴 Rejected → исправь код, new build, resubmit

---

## 📞 Если возникнут вопросы от App Review

**Типичные вопросы:**

**Q: "Why does the app need an account?"**
**A:** "Account is optional. Pickly keeps saved products and preferences on this device. The core scanning and search flow can be tested without signing in."

**Q: "Where does the product data come from?"**
**A:** "Pickly uses Open Food Facts and a curated Supabase catalog for product lookup. Scoring is deterministic and versioned; the app recomputes legacy or inconsistent catalog rows locally."

**Q: "Is Sign in with Apple required?"**
**A:** "Yes, Sign in with Apple is implemented and appears first, alongside Google and email options."

**Q: "Can we test without an account?"**
**A:** "Yes, the app works without signing in. Account access is optional and is not required for the core grocery flow."

---

## 🎉 Перед отправкой

Что уже подготовлено:

⚠️ Локальная Privacy Policy обновлена; публичную версию нужно опубликовать и проверить
✅ Guest review access задокументирован
✅ App Privacy Details (инструкции готовы)
✅ Sign in with Apple реализован
✅ StoreKit интеграция
⚠️ Account deletion UI и Supabase deletion flow готовы; migration, обе Edge Functions и Apple secrets уже настроены в production. Осталась реальная device E2E-проверка Apple auth/token exchange/account deletion.
✅ Camera permission description

**Осталось перед отправкой:**
1. Заполнить App Privacy Details и сверить их с финальным privacy report archive.
2. Провести на физическом iPhone StoreKit purchase/restore, Apple/Google/email auth, password recovery, account deletion и camera/barcode E2E; сверить подписки в App Store Connect.
3. Создать Archive, выбрать именно этот build и добавить скриншоты.

---

**Удачи! 🚀**
