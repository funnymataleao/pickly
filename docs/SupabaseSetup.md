# Pickly Supabase Setup (legacy archive)

> This is a historical migration record, not the active production setup. The current iOS runtime uses Firebase Authentication and the Cloudflare Pickly API. Do not use the Supabase commands, endpoints, secrets, or deletion flow below for a new release.

## Current connection status

The Supabase project described here was used during an earlier migration stage. It is not referenced by the active target, which authenticates through Firebase and sends account-linked requests to Cloudflare. A real-device auth/deletion E2E check remains before release.

Release builds now validate Firebase credentials, Google OAuth client identifiers, and the HTTPS Cloudflare API URL. See `Config/Local.xcconfig.example` and `Scripts/validate-release-config.sh`.

## 1. Project Setup

1. Create a Supabase project in the region closest to the first real audience.
2. In Project Settings, copy:
   - Project URL
   - Publishable key, or legacy anon key if publishable keys are not enabled yet
3. Never put a secret key or service_role key in the iOS app.
4. Enable Auth providers:
   - Email/password authentication with password recovery
   - Sign in with Apple before TestFlight/App Store
5. Add the iOS URL/deep-link handling when Supabase Auth is connected in SwiftUI.

## 2. Recommended Tables

Use this as a first SQL migration in Supabase SQL Editor.

```sql
create extension if not exists pgcrypto;
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

create type product_verdict as enum ('great', 'good', 'okay', 'not_great', 'limited_data');
create type product_confidence as enum ('high', 'medium', 'low');
create type product_request_status as enum ('new', 'reviewing', 'added', 'rejected');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sensitive_digestion boolean not null default false,
  low_sugar boolean not null default false,
  low_sodium boolean not null default false,
  vegetarian boolean not null default false,
  vegan boolean not null default false,
  gluten_free boolean not null default false,
  lactose_free boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  barcode text unique,
  name text not null,
  brand text,
  category text not null default 'Grocery',
  image_url text,
  ingredients text[] not null default '{}',
  nutrition jsonb not null default '{}'::jsonb,
  score integer check (score between 0 and 100),
  verdict product_verdict not null default 'limited_data',
  summary text not null default '',
  reasons text[] not null default '{}',
  warnings text[] not null default '{}',
  positives text[] not null default '{}',
  confidence product_confidence not null default 'low',
  source text not null default 'manual',
  score_version text not null default 'mvp-v1',
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.product_alternatives (
  product_id uuid not null references public.products(id) on delete cascade,
  alternative_product_id uuid not null references public.products(id) on delete cascade,
  reason text not null,
  rank integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (product_id, alternative_product_id),
  check (product_id <> alternative_product_id)
);

create table public.saved_products (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.scan_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  barcode text,
  source text not null default 'barcode' check (source in ('barcode', 'search', 'manual')),
  scanned_at timestamptz not null default now()
);

create table public.product_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  barcode text,
  name text,
  brand text,
  note text,
  status product_request_status not null default 'new',
  created_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger user_preferences_set_updated_at
before update on public.user_preferences
for each row execute function public.set_updated_at();

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create schema if not exists private;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;

  insert into public.user_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();
```

## 3. Indexes

```sql
create index products_barcode_idx on public.products (barcode);
create index products_name_trgm_idx on public.products using gin (name extensions.gin_trgm_ops);
create index products_brand_trgm_idx on public.products using gin (brand extensions.gin_trgm_ops);
create index products_category_idx on public.products (category);
create index product_alternatives_product_rank_idx on public.product_alternatives (product_id, rank);
create index product_alternatives_alternative_product_idx on public.product_alternatives (alternative_product_id);
create index saved_products_user_saved_at_idx on public.saved_products (user_id, saved_at desc);
create index saved_products_product_idx on public.saved_products (product_id);
create index scan_history_user_scanned_at_idx on public.scan_history (user_id, scanned_at desc);
create index scan_history_product_idx on public.scan_history (product_id);
create index product_requests_user_created_at_idx on public.product_requests (user_id, created_at desc);
```

## 4. Row Level Security

```sql
alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.products enable row level security;
alter table public.product_alternatives enable row level security;
alter table public.saved_products enable row level security;
alter table public.scan_history enable row level security;
alter table public.product_requests enable row level security;

grant select on public.products to anon, authenticated;
grant select on public.product_alternatives to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, update on public.user_preferences to authenticated;
grant select, insert, delete on public.saved_products to authenticated;
grant select, insert on public.scan_history to authenticated;
grant select, insert on public.product_requests to authenticated;

create policy "Public can read published products"
on public.products
for select
using (is_published = true);

create policy "Public can read alternatives for published products"
on public.product_alternatives
for select
using (
  exists (
    select 1
    from public.products product
    where product.id = product_id
      and product.is_published = true
  )
);

create policy "Users can read own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "Users can read own preferences"
on public.user_preferences
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can update own preferences"
on public.user_preferences
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can read own saved products"
on public.saved_products
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can save products"
on public.saved_products
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can remove own saved products"
on public.saved_products
for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can read own scan history"
on public.scan_history
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can add own scan history"
on public.scan_history
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can read own product requests"
on public.product_requests
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can request products"
on public.product_requests
for insert
to authenticated
with check ((select auth.uid()) = user_id);
```

## 5. Product Data Rules

- `products` should be readable by the app, but writable only by your backend/admin process.
- Keep scoring deterministic. Store `score_version` so old scores can be audited after scoring updates.
- Do not store medical claims. Keep warnings as grocery guidance.
- `nutrition` can start as JSONB for speed, then move high-query fields to columns if search/filtering needs it.
- Product photos can stay as external URLs first. Add Supabase Storage later only for user-submitted request photos.

## 6. iOS Integration Order

1. Keep the lightweight URLSession Supabase client behind `SupabaseProductService`.
2. Let `ProductCatalogStore` load published products from Supabase before using Open Food Facts.
3. Keep anonymous/local mode working for users who do not sign in.
4. Keep product search and barcode lookup behind `ProductService`/`ProductLookupService`, not in SwiftUI views.
5. Add authenticated cloud saved-product sync later if the MVP needs multi-device state.

## 7. iOS configuration and account deletion

`SupabaseCredentials` reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from `PicklyAppInfo.plist`. The target uses `Config/Base.xcconfig`, which supplies empty build-safe defaults and optionally includes the ignored `Config/Local.xcconfig`. CI or archive automation must inject the public runtime values. Do not put credentials into Swift source. The app uses only the publishable key. A `service_role` key must never be embedded in the app.

Deploy `supabase/functions/delete-account/index.ts` as an Edge Function named `delete-account` with JWT verification enabled. Also deploy `supabase/functions/apple-token/index.ts`; it exchanges the one-time native Apple authorization code for Apple's refresh token and stores only that refresh token server-side. The production migration `supabase/migrations/20260809105116_apple_provider_tokens.sql` and both functions are already deployed; repeat the commands below only when promoting a new version.

Configure these secrets in Supabase Function Secrets (never in the iOS target):

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` (or `SUPABASE_ANON_KEY`)
- `SUPABASE_SERVICE_ROLE_KEY`
- `APPLE_CLIENT_ID` (`com.pickly.app.Pickly`)
- Either `APPLE_CLIENT_SECRET`, or `APPLE_TEAM_ID`, `APPLE_KEY_ID`, and `APPLE_PRIVATE_KEY` containing the `.p8` key.

The service role is used only inside the functions. Apple deletion revokes the stored refresh token first and only then deletes the Supabase user. If the Apple secrets, token row, or revoke call are unavailable, deletion returns an explicit error instead of silently deleting an account while leaving the Apple grant active.

From the repository root, the deploy sequence is:

```bash
supabase link --project-ref bslsanvmkwjzbjerpzpi
supabase db push
supabase functions deploy apple-token
supabase functions deploy delete-account
supabase secrets set \
  APPLE_CLIENT_ID=com.pickly.app.Pickly \
  APPLE_TEAM_ID=... \
  APPLE_KEY_ID=... \
  APPLE_PRIVATE_KEY="$(cat /secure/path/AuthKey_XXXXXXXXXX.p8)"
```

Use `APPLE_CLIENT_SECRET` instead of the team/key/private-key trio only when you have a managed rotation process for that JWT; generated client secrets expire and must be rotated before deletion is needed.

The deployed project was verified through the Auth settings endpoint, the public `products` REST endpoint (30 products and 17 alternative relations), and unauthenticated requests to both deletion/token functions (which correctly return `401`). Security advisors report the intentional no-policy state for the service-role-only token table. Leaked Password Protection was attempted through the Management API but the hosted Free plan rejected it with HTTP 402; enable it in the Supabase Dashboard after upgrading to Pro. Performance advisors report informational `unused_index` notices for indexes that have not yet been exercised by production traffic.

## 8. Native Apple and Google sign-in

Pickly uses native provider SDKs and exchanges their ID tokens for a Supabase session. The iOS app never stores an Apple private key, a Google client secret, a Supabase secret key, or a `service_role` key.

### Sign in with Apple

1. In Apple Developer, enable **Sign in with Apple** for App ID `com.pickly.app.Pickly`.
2. In Xcode, keep `Pickly/Pickly.entitlements` attached to both Debug and Release. It contains the `com.apple.developer.applesignin` entitlement.
3. In Supabase Dashboard → Authentication → Sign In / Providers → Apple:
   - Enable Apple.
   - Add `com.pickly.app.Pickly` under Client IDs.
4. Native-only Apple sign-in can work without a Services ID, web redirect, or client secret for the initial login. The app sends the one-time native authorization code to the `apple-token` Edge Function after Supabase login; that function exchanges it with Apple and stores the refresh token for later deletion. Configure the server-side Apple client secret/private key before enabling production account deletion.

The app requests name and email only when the user starts Apple sign-in. It sends a SHA-256 nonce to Apple and the original nonce to Supabase to prevent token replay. Apple supplies a person's name only on first authorization, so Pickly saves that name to Supabase user metadata when it is available.

### Sign in with Google

1. In Google Auth Platform, configure the consent screen with only `openid`, email, and profile scopes, plus Pickly's privacy-policy and terms URLs before release.
2. Create two OAuth client IDs:
   - **iOS** client with bundle ID `com.pickly.app.Pickly`.
   - **Web application** client used as the ID-token server audience.
3. In Supabase Dashboard → Authentication → Sign In / Providers → Google:
   - Enable Google.
   - Add the Web client ID first and the iOS client ID second under Client IDs.
   - Keep nonce verification enabled. Pickly uses Google Sign-In's nonce API and passes the matching original nonce to Supabase.
4. Copy `docs/Supabase.local.xcconfig.example` values into the ignored `Config/Local.xcconfig`:
   - `GOOGLE_IOS_CLIENT_ID`
   - `GOOGLE_SERVER_CLIENT_ID` (the Web client ID)
   - `GOOGLE_REVERSED_CLIENT_ID` (the reversed iOS client ID used as the callback URL scheme)

Google OAuth client IDs are public identifiers, but keep environment-specific values in the ignored config. Never add a Google client secret to the app.

### Verification

Test Apple sign-in on a signed physical device. Test Google sign-in on both the simulator and a signed device. For each provider verify first sign-in, returning sign-in, cancellation, app relaunch/session refresh, sign-out, and in-app account deletion. Confirm the resulting user and identity under Supabase Authentication → Users, and confirm that no provider token or secret appears in app logs.
