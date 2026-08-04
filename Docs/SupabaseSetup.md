# Pickly Supabase Setup

This is the recommended backend shape for the Pickly MVP. Keep the app local/mock-first until the core UX is stable, then connect these tables behind service protocols.

## Current connection status

Pickly is connected to Supabase project `bslsanvmkwjzbjerpzpi` in the `eu-west-1` region. The schema, RLS policies, private auth trigger, `delete-account` Edge Function, and six verified Open Food Facts catalog snapshots are deployed. The app reads Supabase first, then falls back to Open Food Facts for barcode lookup and search; no `service_role` key is shipped to iOS.

## 1. Project Setup

1. Create a Supabase project in the region closest to the first real audience.
2. In Project Settings, copy:
   - Project URL
   - Publishable key, or legacy anon key if publishable keys are not enabled yet
3. Never put a secret key or service_role key in the iOS app.
4. Enable Auth providers:
   - Email OTP for fast MVP testing
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

`SupabaseCredentials` reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from `PicklyAppInfo.plist`, populated by the ignored `Config/Local.xcconfig` attached to the Pickly target. Do not put credentials back into Swift source. The app uses only the publishable key. A `service_role` key must never be embedded in the app.

Deploy `supabase/functions/delete-account/index.ts` as an Edge Function named `delete-account` with JWT verification enabled. Configure the function's server-side secrets (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`) in Supabase Function Secrets. The service role is used only inside that function to revoke the user's session and delete the authenticated user, which keeps account deletion compatible with Apple's account-deletion requirement without exposing an admin key to iOS.

The deployed project was verified through the Auth settings endpoint, the public `products` REST endpoint, a catalog response containing six rows, and an unauthenticated deletion request (which correctly returns `401`). Security advisors are clean. Performance advisors only report expected informational `unused_index` notices for indexes that have not yet been exercised by production traffic.
