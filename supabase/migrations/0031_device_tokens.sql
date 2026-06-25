-- FCM push: per-device tokens. The client upserts its own token (RLS owner);
-- the backend (service role) reads them to send notifications.

create table if not exists device_tokens (
  token      text primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  platform   text not null default 'android',
  updated_at timestamptz not null default now()
);
create index if not exists idx_device_tokens_profile on device_tokens(profile_id);

alter table device_tokens enable row level security;
drop policy if exists "own device tokens" on device_tokens;
create policy "own device tokens" on device_tokens for all to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
