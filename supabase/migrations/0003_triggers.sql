-- Mesh — triggers & automation
-- Run AFTER 0002_rls_policies.sql.

-- ── Auto-provision a profile row when a new auth user is created ─────────────
-- Generates a temporary unique username (refined during onboarding). Pulls a
-- display name / username hint from OAuth metadata when available.
create or replace function handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  base_username text;
begin
  base_username := coalesce(
    new.raw_user_meta_data->>'user_name',   -- GitHub
    new.raw_user_meta_data->>'preferred_username',
    split_part(coalesce(new.email, 'mesher'), '@', 1)
  );

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    -- guarantee uniqueness by suffixing a short slice of the uuid
    base_username || '_' || substr(new.id::text, 1, 6),
    new.raw_user_meta_data->>'full_name'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ── Keep profiles.updated_at current ────────────────────────────────────────
create or replace function touch_updated_at()
returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on profiles;
create trigger profiles_touch_updated_at
  before update on profiles
  for each row execute function touch_updated_at();
