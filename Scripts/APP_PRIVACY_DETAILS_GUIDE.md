# App Privacy Details для Pickly

Полная инструкция по заполнению раздела **App Privacy** в App Store Connect.

## Где заполнять

1. Открой: https://appstoreconnect.apple.com
2. Выбери **Pickly**
3. Перейди в **App Privacy** (в левом меню)
4. Нажми **Get Started** (или **Edit** если уже начинал)

---

## Шаг 1: Типы данных, которые собирает Pickly

Apple спросит: **"Does your app collect data from this app?"**

✅ **Ответ: YES**

Pickly и встроенные SDK собирают или передают для работы функции:
- Email и User ID (для Firebase Authentication и связанных функций аккаунта)
- Name, если он предоставлен Apple или Google
- Product Interactions (поисковые запросы и баркоды для поиска)
- Локальная проверка verified subscription status через StoreKit для доступа к Pickly Plus; транзакции и purchase history не отправляются на сервер Pickly
- Firebase Authentication 12.18.0 декларирует в bundled privacy manifest User ID (linked, App Functionality) и Other Diagnostic Data (not linked, Analytics). Tracking: No.
- Google Sign-In 9.2.0 декларирует в bundled privacy manifest: Name, Email Address, Phone Number, User ID, Coarse Location, Device ID, Other Data Types и Other Usage Data. Часть типов используется для App Functionality, а User ID, Device ID, Other Data Types и Other Usage Data также декларируются для Analytics. Tracking: No.

При удалении Apple-аккаунта пользователь повторно подтверждает личность через Sign in with Apple. Свежий одноразовый authorization code используется транзитно для отзыва Apple connection; Pickly не хранит долгоживущие Apple authorization codes или refresh tokens.

---

## Шаг 2: Заполнение по категориям

### 📧 Contact Info

**Выбери:** ✅ **Name**

- Collected: **Yes**, когда имя передаёт выбранный identity provider
- Linked to identity: **Yes**
- Tracking: **No**
- Purpose: **App Functionality**

**Выбери:** ✅ **Email Address**

**Настройки для Email Address:**

1. **Is the Email Address data collected from this app?**
   - ✅ **Yes**

2. **Is the Email Address data linked to the user's identity?**
   - ✅ **Yes** (привязан к аккаунту пользователя)

3. **Do you or your third-party partners use Email Address data for tracking purposes?**
   - ❌ **No**

4. **For what purposes do you or your third-party partners use Email Address data?**
   - ✅ **App Functionality** (для создания и входа в аккаунт)
   - ❌ Не выбирай: Analytics, Product Personalization, Advertising, Other

---

### 🆔 Identifiers

**Выбери:** ✅ **User ID**

**Настройки для User ID:**

1. **Is the User ID data collected from this app?**
   - ✅ **Yes**

2. **Is the User ID data linked to the user's identity?**
   - ✅ **Yes** (это UUID пользователя в Firebase Authentication)

3. **Do you or your third-party partners use User ID data for tracking purposes?**
   - ❌ **No**

4. **For what purposes do you or your third-party partners use User ID data?**
   - ✅ **App Functionality** (для account access and account-related functionality)
   - ✅ **Analytics** (декларируется bundled manifest Google Sign-In SDK)
   - ❌ Не выбирай: Product Personalization, Advertising, Other

**Выбери:** ✅ **Device ID**

- Linked to identity: **Yes**
- Tracking: **No**
- Purpose: **Analytics** (декларируется bundled manifest Google Sign-In SDK)

### 📍 Location

**Выбери:** ✅ **Coarse Location**

- Linked to identity: **Yes**
- Tracking: **No**
- Purpose: **App Functionality**
- Pickly не запрашивает системное разрешение Location; эта декларация отражает connection data, указанное Google Sign-In SDK

### 📱 Google Sign-In service data

**Выбери:** ✅ **Phone Number**

- Linked: **Yes**
- Tracking: **No**
- Purpose: **App Functionality**
- Может присутствовать в выбранном Google account; Pickly напрямую его не запрашивает и не сохраняет в профиле

**Выбери:** ✅ **Other Data Types** и ✅ **Other Usage Data**

- Linked: **Yes**
- Tracking: **No**
- Purpose: **Analytics**
- Для Other Data Types также отметь **App Functionality**

---

### 📊 Usage Data

**Выбери:** ✅ **Product Interaction**

**Настройки для Product Interaction:**

1. **Is the Product Interaction data collected from this app?**
   - ✅ **Yes**

2. **Is the Product Interaction data linked to the user's identity?**
   - ✅ **Yes** (обычный lookup не требует аккаунта, но отправленная заявка на отсутствующий продукт сохраняется с Firebase User ID в Cloudflare)

3. **Do you or your third-party partners use Product Interaction data for tracking purposes?**
   - ❌ **No**

4. **For what purposes do you or your third-party partners use Product Interaction data?**
   - ✅ **App Functionality** (для поиска информации о продуктах)
   - ❌ Не выбирай: Analytics, Product Personalization, Advertising, Other

### 🛒 Purchases

**Не выбирай Purchase History для текущей версии.**

- StoreKit entitlement проверяется локально через `Transaction.currentEntitlements`.
- Pickly не отправляет транзакции или историю покупок в Cloudflare/Firebase и не хранит их на своём сервере.
- Payment card details Pickly не получает и не хранит.
- Данные, которые обрабатывает Apple в рамках StoreKit и которые не передаются разработчику для длительного хранения, не являются collected data Pickly для App Privacy.

### 🛠 Diagnostics

**Выбери:** ✅ **Other Diagnostic Data**

- Linked to identity: **No**
- Tracking: **No**
- Purpose: **Analytics**
- Source: bundled privacy manifest Firebase Authentication 12.18.0
- Не выбирай Crash Data или Performance Data: отдельный Firebase Crashlytics или другой crash-reporting SDK в target не подключён

---

## Шаг 3: Типы данных, которые НЕ собираются

Apple покажет список категорий. **НЕ выбирай** следующие:

❌ **Health & Fitness** — не собираем
❌ **Financial Info** — не собираем
❌ **Precise Location** — системное разрешение геолокации не запрашивается; Coarse Location раскрывается из-за Google Sign-In SDK
❌ **Sensitive Info** — не собираем
❌ **Contacts** — не собираем
❌ **User Content** — приложение не содержит UGC
❌ **Browsing History** — не собираем
❌ **Search History** — не хранится как история поиска; запросы, которые нужны для каталога, передаются как Product Interaction и должны быть сверены с фактическим Release flow
❌ **Crash Data** и **Performance Data** — отдельный crash-reporting/performance SDK не подключён. При этом **Other Diagnostic Data нужно выбрать** из-за bundled manifest Firebase Authentication.

---

## Шаг 4: Проверка и подтверждение

После заполнения Apple покажет **summary**:

### Проверка перед публикацией:

Не публикуй этот список автоматически. Сначала собери Release archive и проверь aggregated privacy report: third-party SDK privacy manifests являются частью ответственности разработчика. Ответы App Privacy, публичная Privacy Policy и текст внутри приложения должны описывать один и тот же фактический flow.

**Ожидаемые категории для проверки:**
- Email Address (linked, App Functionality) и User ID (linked, App Functionality + Analytics)
- Name, если его реально получает выбранный provider
- Product Interaction (linked из-за account-scoped product requests)
- Phone Number и Coarse Location (linked, App Functionality, No tracking; Google Sign-In SDK)
- Device ID (linked, Analytics, No tracking; Google Sign-In SDK)
- Other Data Types (linked, App Functionality + Analytics, No tracking; Google Sign-In SDK)
- Other Usage Data (linked, Analytics, No tracking; Google Sign-In SDK)
- Other Diagnostic Data (not linked, Analytics, No tracking; Firebase Authentication)

**Data NOT Collected:**
- ❌ Precise Location
- ❌ Contacts
- ❌ Photos
- ❌ Health
- ❌ Financial Info
- ❌ Browsing/Search History
- ❌ Advertising Data
- ❌ Purchase History (StoreKit-only, не передаётся на сервер Pickly)

---

## Шаг 5: Третьи стороны (Third-Party Partners)

Apple спросит: **"Do any third parties have access to data collected from your app?"**

✅ **Ответ: YES**

**Укажи третьи стороны:**

1. **Firebase Authentication**
   - Purpose: Optional authentication and account management
   - Data shared: Email, User ID, provider name data, and unlinked Other Diagnostic Data declared by the SDK

2. **Cloudflare**
   - Purpose: Product catalog and account-linked request storage
   - Data shared: Product search requests, barcodes, and submitted product request details

3. **Open Food Facts**
   - Purpose: Product information lookup
   - Data shared: Product barcodes (anonymous)

4. **Google Sign-In** (если используется)
   - Purpose: Authentication
   - Data processed according to the bundled SDK manifest: Name, Email Address, Phone Number, User ID, Coarse Location, Device ID, Other Data Types, Other Usage Data
   - Tracking: No

**Важно:** Укажи, что все третьи стороны имеют собственные Privacy Policies. Данные используются для App Functionality и для ограниченных Analytics purposes, которые прямо перечислены в bundled SDK privacy manifests; tracking и advertising не используются.

---

## Шаг 6: Сохранить черновик и сверить Release archive

1. **Проверь всё еще раз**
2. Сохрани все ответы в draft, но пока не нажимай **Publish**
3. Собери Release archive и сверь aggregated privacy report с этим документом и публичной Privacy Policy
4. Нажимай **Publish** только после этой сверки

---

## ⚠️ Частые ошибки

### ❌ НЕ выбирай "Tracking"
Если выберешь "Used for tracking", Apple потребует ATTrackingTransparency (ATT) prompt. Pickly **не использует** tracking.

### ❌ НЕ выбирай "Advertising"
Pickly не показывает рекламу и не использует advertising networks.

### ❌ Не добавляй рекламную аналитику
В текущем target нет Google Analytics, Firebase Analytics или рекламного SDK. Но **Analytics** нужно выбрать для User ID, Device ID, Other Data Types и Other Usage Data из privacy manifest Google Sign-In 9.2.0, а также для unlinked Other Diagnostic Data из privacy manifest Firebase Authentication 12.18.0.

### ❌ НЕ выбирай "Search History"
Поиск может передаваться каталогу для выполнения запроса, но Pickly не заявляет и не использует отдельную историю поиска или tracking-профиль. Сверь фактический Release data flow перед публикацией.

---

## 📄 Связь с Privacy Policy

Убедись что твой Privacy Policy (https://funnymataleao.github.io/pickly/privacy.html) соответствует тому, что указано в App Privacy Details:

✅ Email и User ID → упомянуты в Privacy Policy
✅ Name/provider data → упомянуты, если реально получаются
✅ Product searches и barcodes → упомянуты в Privacy Policy
✅ Third parties (Firebase Authentication, Cloudflare, Open Food Facts) → упомянуты в Privacy Policy
✅ StoreKit subscription status → упомянут в Privacy Policy
✅ Google Sign-In service data and limited SDK analytics → упомянуты в Privacy Policy
✅ Firebase Authentication Other Diagnostic Data (unlinked analytics) → упомянуты в Privacy Policy

---

## 🎯 Готово!

После заполнения App Privacy Details повторно проверь privacy report, публичную policy и релизные notes. Этот документ сам по себе не является доказательством готовности к отправке.

---

## Нужна помощь?

Если Apple отклонит из-за Privacy:
1. Проверь что Privacy Policy URL доступен
2. Проверь что App Privacy Details совпадают с Privacy Policy
3. Проверь что не выбрал "Tracking" или "Advertising" по ошибке
4. Напиши в App Review Notes, что приложение работает без аккаунта и не использует tracking
