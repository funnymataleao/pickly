create table if not exists public.apple_provider_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.apple_provider_tokens enable row level security;

revoke all on table public.apple_provider_tokens from anon, authenticated;

create index if not exists apple_provider_tokens_updated_at_idx
  on public.apple_provider_tokens (updated_at);
