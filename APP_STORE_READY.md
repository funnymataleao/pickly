# 🚀 Pickly - Готовность к App Store

Финальный чеклист перед отправкой в App Review.

---

## ✅ Подготовлено к финальной проверке

### 1. Privacy Policy ✅
**URL:** https://funnymataleao.github.io/pickly/privacy.html

**Статус:** обновление от 28 августа с раскрытием Firebase Authentication diagnostics и on-device StoreKit flow опубликовано через GitHub Pages и проверено по публичному URL.

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
- Notes:
  "Account access is optional. Saved products and preferences stay on this device. Reviewers can use barcode scanning, manual barcode entry, product search, scoring, and explanations without signing in.

  Pickly Plus is an optional auto-renewable subscription that provides ongoing access to Pickly's live catalog-matching service: additional goal-based matches on Home, current higher-scoring matches on Product Result, and side-by-side comparison. Pickly refreshes its published catalog at launch and queries current catalog sources on demand for search, goal recommendations, and better choices, so available matches can evolve as catalog data changes. Reviewers can always open Profile → Pickly Plus; contextual entry points also appear at Home → Better choices and Product Result → Better choices when matching content is available. Monthly product ID: com.pickly.plus.monthly. Annual product ID: com.pickly.plus.annual.

  Scoring is deterministic and uses available nutrition and ingredient data. Pickly provides general grocery information, not medical advice, and does not diagnose, treat, cure, or prevent disease. The methodology is available from Product Result → How scoring works, Profile → How scoring works, and the Pickly Plus screen."

---

### 3. App Privacy Details ⏳
**Статус:** в App Store Connect выбраны и настроены 10 фактических data types; Purchase History удалён. User ID настроен для App Functionality + Analytics, linked, no tracking. Кнопка Publish активна, но публиковать label нужно только после Release privacy report.

**Инструкции:**
- Полная: `Scripts/APP_PRIVACY_DETAILS_GUIDE.md`
- Краткая: `Scripts/APP_PRIVACY_CHECKLIST.md`

**Быстрый summary:**
- Name (Linked, App Functionality, No tracking; only when supplied by an identity provider)
- Email Address (Linked, App Functionality, No tracking)
- User ID (Linked, App Functionality + Analytics, No tracking)
- Product Interaction (Linked for submitted product requests, App Functionality, No tracking)
- Google Sign-In SDK service data: Phone Number, Coarse Location, Device ID, Other Data Types и Other Usage Data — по bundled privacy manifest 9.2.0
- Other Diagnostic Data (Not linked, Analytics, No tracking; Firebase Authentication 12.18.0)
- Purchase History не выбирается: entitlement проверяется локально через StoreKit и не передаётся на сервер Pickly
- Third parties: Firebase Authentication, Cloudflare, Open Food Facts, Google Sign-In

---

## 📋 Финальный Pre-Submission Checklist

### В App Store Connect:

- [ ] **App Information**
  - [ ] Privacy Policy URL добавлен
  - [ ] Category выбрана (рекомендуется Food & Drink)
  - [ ] Age Rating настроен
  - [ ] Copyright заполнен

- [ ] **App Privacy**
  - [x] Email Address настроен
  - [x] Name настроен
  - [x] User ID настроен: App Functionality + Analytics
  - [x] Phone Number и Coarse Location настроены по Google Sign-In manifest
  - [x] Device ID и Other Usage Data настроены по Google Sign-In manifest
  - [x] Other Data Types настроен: App Functionality + Analytics, linked, no tracking
  - [x] Product Interaction настроен
  - [x] Other Diagnostic Data настроен по Firebase Authentication manifest
  - [x] Purchase History удалён для текущего StoreKit-only flow
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

- [ ] **Свежий release-candidate build** собран и протестирован после текущих изменений
- [x] **Локальная Release-сборка для generic iOS Simulator** прошла 28 августа 2026 года на Xcode 27 beta
- [x] **Bundle ID:** com.pickly.app.Pickly
- [x] **Version:** 1.0
- [x] **Build number:** 1
- [ ] **Sign in with Apple** работает на реальном устройстве
- [ ] **Google Sign-In** работает (если настроен)
- [x] **StoreKit Configuration** добавлен в проект (PicklySubscriptions.storekit)
- [x] **Supported devices:** только iPhone; основной сценарий — сканирование в магазине
- [ ] **Archive пересобран из текущего HEAD** и успешно экспортирован как App Store Connect IPA с Apple Distribution signature
- [ ] **IPA загружен** в App Store Connect через Xcode Organizer/Transporter

### Функциональные тесты:

Текущий локальный результат — **97/97 passed** на Pickly App Store Audit Simulator (iOS 26.5) и успешная Release-сборка для generic iOS Simulator, 28 августа 2026 года. Обе проверки выполнены на локальном Xcode 27 beta и подтверждают source/build evidence, но не заменяют stable Xcode Cloud archive, TestFlight или физический iPhone.

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

### 1. Заверши и сверь App Privacy draft
После Xcode Cloud archive сверь aggregated privacy report с `Scripts/APP_PRIVACY_DETAILS_GUIDE.md`. До этой сверки не нажимай Publish.

### 2. Создай Xcode Cloud workflow и загрузи archive

Локально установлен beta Xcode, поэтому distribution archive для отправки нужно собрать в Xcode Cloud на stable Xcode 26. `ci_scripts/ci_post_clone.sh` уже готовит ignored `Config/Local.xcconfig` из secret environment variables без вывода значений в лог. Перед запуском workflow закоммить и отправь точный release candidate, настрой release secrets из `Scripts/validate-release-config.sh`, затем выбери обработанный cloud build в App Store Connect.

### 3. Заполни существующую версию 1.0 в App Store Connect
1. Открой iOS 1.0 со статусом Prepare for Submission
2. Добавь iPhone-скриншоты для размеров, которые App Store Connect требует у текущей версии
3. Заполни App Description и остальные metadata fields
4. Выбери обработанный Build
5. Submit for Review

---

## 📸 Скриншоты (нужны для App Store)

**Минимально нужны:**
- Наборы размеров iPhone, которые показывает App Store Connect для текущей версии.
- Не растягивай и не ресайзь один скриншот под другое соотношение сторон.

**Рекомендуемые скриншоты:**
1. Onboarding / Home screen с поиском
2. Scan barcode (камера в действии)
3. Product Result (с verdict и score)
4. Pickly Plus — доступные Better choices и сравнение; прямо обозначить на скриншоте, что функция требует подписку
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
Scan barcodes for calm grocery guidance. Scores are free; Pickly Plus provides ongoing access to live product matches and side-by-side comparisons.

**Description:**
```
Pickly helps you make better grocery choices quickly and calmly.

Scan a product barcode or search the catalog for free to see:
• Clear verdict: Great, Good, Okay, or Not great
• Plain-language explanation of the score
• What to watch (sugar, sodium, saturated fat, additives)
• Personalized notes based on your preferences

No panic. No shame. Just calm, clear guidance.

Features:
• Barcode scanner
• Product search
• Explainable scoring
• Save products for later
• Set dietary preferences
• Optional account sign-in

Pickly Plus is an optional auto-renewable subscription that provides ongoing access to live catalog matching:
• Current goal-based product matches
• Current higher-scoring choices for the scanned or searched item
• Side-by-side comparison with a selected alternative

Pickly refreshes remote catalog data and matching results as you search, scan, and compare. Match availability depends on the current catalog data available for each item. On Product Result, the Better choices section does not offer a subscription entry point when no higher-scoring matches are available.

Pickly focuses on grocery and supermarket food products. Pickly uses its verified catalog and Open Food Facts for product data.

Pickly scores are deterministic comparisons based on available nutrition and ingredient data. Pickly provides general grocery information, not medical advice, and does not diagnose, treat, cure, or prevent disease.

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
https://funnymataleao.github.io/pickly/support.html
```

**Support email:**
```
mail@denisefremov.com
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
**A:** "Pickly uses Open Food Facts and Pickly's published Cloudflare catalog for product lookup. Scoring is deterministic and versioned; the app recomputes legacy or inconsistent catalog rows locally."

**Q: "Is Sign in with Apple required?"**
**A:** "Yes, Sign in with Apple is implemented and appears first, alongside Google and email options."

**Q: "Can we test without an account?"**
**A:** "Yes, the app works without signing in. Account access is optional and is not required for the core grocery flow."

**Q: "What does Pickly Plus unlock?"**
**A:** "Pickly Plus provides ongoing access to live catalog matching: additional goal-based matches on Home, current higher-scoring choices, and side-by-side comparison on Product Result. Pickly refreshes published catalog data at launch and queries current catalog sources on demand. The subscription is not offered from a product result when no higher-scoring matches are available."

**Q: "How does scoring work, and is it medical advice?"**
**A:** "Each complete result starts at 75 and is adjusted using available sugar, salt, saturated fat, protein, fiber, ingredient-list length, and listed additives. Missing or conflicting data lowers confidence, and missing core nutrition fields produces Limited data instead of a score. Pickly provides general grocery information, not medical advice. The complete methodology is available inside the app from Product Result, Profile, and the Pickly Plus screen."

---

## 🎉 Перед отправкой

Что уже подготовлено:

✅ Privacy Policy и Support page опубликованы и доступны без авторизации
✅ Guest review access задокументирован
⚠️ App Privacy draft: 10 типов настроены, кнопка Publish активна; сверить Release privacy report перед Publish
✅ Sign in with Apple реализован
✅ StoreKit интеграция
⚠️ Account deletion UI теперь требует свежую Apple re-authentication для Apple-аккаунтов, удаляет данные из Cloudflare до удаления Firebase-пользователя и отзывает Apple connection. Осталась реальная device E2E-проверка Apple/Google/email auth и account deletion.
✅ Camera permission description
✅ Шесть App Store JPG экспортированы в `~/Downloads/Pickly-AppStore-Screenshots` (1242×2688, RGB, без alpha)

**Осталось перед отправкой:**
1. Принять обновлённое Apple Developer Program License Agreement владельцем аккаунта.
2. Загрузить метаданные и шесть скриншотов; публиковать privacy label только после сверки Release privacy report.
3. Закоммитить и отправить точный release candidate, настроить Xcode Cloud workflow на stable Xcode 26 и выбрать обработанный build в App Store Connect.
4. Провести на физическом iPhone StoreKit purchase/restore, Apple/Google/email auth, email password reset, account deletion и camera/barcode E2E; сверить подписки в App Store Connect.

---

**Удачи! 🚀**
