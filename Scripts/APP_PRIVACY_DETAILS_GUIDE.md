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

Pickly собирает или передаёт для работы функции:
- Email и User ID (для аккаунта Supabase)
- Name, если он предоставлен Apple или Google
- Product Interactions (поисковые запросы и баркоды для поиска)
- Verified subscription status для доступа к Pickly Plus

Sign in with Apple также отправляет одноразовый authorization code на сервер Pickly для обмена на provider refresh token. Refresh token хранится только на сервере как credential для отзыва Apple connection при удалении аккаунта; он не попадает в приложение и не используется для tracking.

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
   - ✅ **Yes** (это UUID пользователя в Supabase)

3. **Do you or your third-party partners use User ID data for tracking purposes?**
   - ❌ **No**

4. **For what purposes do you or your third-party partners use User ID data?**
   - ✅ **App Functionality** (для account access and account-related functionality)
   - ❌ Не выбирай: Analytics, Product Personalization, Advertising, Other

---

### 📊 Usage Data

**Выбери:** ✅ **Product Interaction**

**Настройки для Product Interaction:**

1. **Is the Product Interaction data collected from this app?**
   - ✅ **Yes**

2. **Is the Product Interaction data linked to the user's identity?**
   - ✅ **Yes** (обычный lookup не требует аккаунта, но отправленная заявка на отсутствующий продукт сохраняется с Supabase User ID)

3. **Do you or your third-party partners use Product Interaction data for tracking purposes?**
   - ❌ **No**

4. **For what purposes do you or your third-party partners use Product Interaction data?**
   - ✅ **App Functionality** (для поиска информации о продуктах)
   - ❌ Не выбирай: Analytics, Product Personalization, Advertising, Other

### 🛒 Purchases

**Выбери:** ✅ **Purchase History**

- Collected: **Yes**
- Linked to identity: **Yes**
- Tracking: **No**
- Purpose: **App Functionality** (StoreKit entitlement открывает Pickly Plus)
- Payment card details Pickly не получает и не хранит

---

## Шаг 3: Типы данных, которые НЕ собираются

Apple покажет список категорий. **НЕ выбирай** следующие:

❌ **Health & Fitness** — не собираем
❌ **Financial Info** — не собираем
❌ **Location** — приложение не запрашивает геолокацию; сверить с финальным privacy report SDK
❌ **Sensitive Info** — не собираем
❌ **Contacts** — не собираем
❌ **User Content** — приложение не содержит UGC
❌ **Browsing History** — не собираем
❌ **Search History** — не хранится как история поиска; запросы, которые нужны для каталога, передаются как Product Interaction и должны быть сверены с фактическим Release flow
❌ **Identifiers** → Device ID — приложение само его не запрашивает; сверить с финальным privacy report SDK
❌ **Diagnostics** — отдельный crash-reporting SDK не подключён; сверить с финальным privacy report SDK
❌ **Other Data** — не добавлять без подтверждения фактическим data flow

---

## Шаг 4: Проверка и подтверждение

После заполнения Apple покажет **summary**:

### Проверка перед публикацией:

Не публикуй этот список автоматически. Сначала собери Release archive и проверь aggregated privacy report: third-party SDK privacy manifests являются частью ответственности разработчика. Ответы App Privacy, публичная Privacy Policy и текст внутри приложения должны описывать один и тот же фактический flow.

**Ожидаемые категории для проверки:**
- Email Address и User ID (linked, App Functionality)
- Name, если его реально получает выбранный provider
- Product Interaction (linked из-за account-scoped product requests)
- Purchase History (linked, App Functionality)

**Data NOT Collected:**
- ❌ Location
- ❌ Contacts
- ❌ Photos
- ❌ Health
- ❌ Financial Info
- ❌ Browsing/Search History
- ❌ Device ID
- ❌ Advertising Data

---

## Шаг 5: Третьи стороны (Third-Party Partners)

Apple спросит: **"Do any third parties have access to data collected from your app?"**

✅ **Ответ: YES**

**Укажи третьи стороны:**

1. **Supabase**
   - Purpose: Backend infrastructure, authentication, database
   - Data shared: Email, User ID, Product searches

2. **Open Food Facts**
   - Purpose: Product information lookup
   - Data shared: Product barcodes (anonymous)

3. **Google Sign-In** (если используется)
   - Purpose: Authentication
   - Data shared: Email, Name (optional)

**Важно:** Укажи что все третьи стороны имеют собственные Privacy Policies и что данные используются только для функционала приложения.

---

## Шаг 6: Сохранить и опубликовать

1. **Проверь всё еще раз**
2. Нажми **Publish**
3. App Privacy Details теперь видны в App Store Connect

---

## ⚠️ Частые ошибки

### ❌ НЕ выбирай "Tracking"
Если выберешь "Used for tracking", Apple потребует ATTrackingTransparency (ATT) prompt. Pickly **не использует** tracking.

### ❌ НЕ выбирай "Advertising"
Pickly не показывает рекламу и не использует advertising networks.

### ❌ НЕ выбирай "Analytics"
В текущем Release нет отдельного analytics SDK (Google Analytics, Firebase Analytics и т. п.).

### ❌ НЕ выбирай "Search History"
Поиск может передаваться каталогу для выполнения запроса, но Pickly не заявляет и не использует отдельную историю поиска или tracking-профиль. Сверь фактический Release data flow перед публикацией.

---

## 📄 Связь с Privacy Policy

Убедись что твой Privacy Policy (https://funnymataleao.github.io/pickly/privacy.html) соответствует тому, что указано в App Privacy Details:

✅ Email и User ID → упомянуты в Privacy Policy
✅ Name/provider data → упомянуты, если реально получаются
✅ Product searches и barcodes → упомянуты в Privacy Policy
✅ Third parties (Supabase, Open Food Facts) → упомянуты в Privacy Policy
✅ StoreKit subscription status → упомянут в Privacy Policy

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
