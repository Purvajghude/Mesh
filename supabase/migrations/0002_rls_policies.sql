-- Mesh — Row Level Security
-- Run AFTER 0001_initial_schema.sql. The anon/publishable key is public, so
-- every table must be locked down: RLS is the real authorization layer.

-- Enable RLS everywhere.
alter table profiles            enable row level security;
alter table skills              enable row level security;
alter table profile_skills      enable row level security;
alter table swipes              enable row level security;
alter table matches             enable row level security;
alter table messages            enable row level security;
alter table collabs             enable row level security;
alter table collab_members      enable row level security;
alter table feed_posts          enable row level security;
alter table behavioral_signals  enable row level security;
alter table cosmetic_unlocks    enable row level security;
alter table safety_checkins     enable row level security;

-- Helper: is the current user a participant in a given match?
create or replace function is_match_participant(p_match uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from matches m
    where m.id = p_match
      and auth.uid() in (m.user_a, m.user_b)
  );
$$;

-- ── profiles ────────────────────────────────────────────────────────────────
-- Discovery app: any signed-in user can read profiles. You may only write yours.
create policy "profiles readable by authenticated"
  on profiles for select to authenticated using (true);
create policy "insert own profile"
  on profiles for insert to authenticated with check (auth.uid() = id);
create policy "update own profile"
  on profiles for update to authenticated using (auth.uid() = id);

-- ── skills (shared catalog) ─────────────────────────────────────────────────
create policy "skills readable by authenticated"
  on skills for select to authenticated using (true);
create policy "authenticated can add skills"
  on skills for insert to authenticated with check (true);

-- ── profile_skills ──────────────────────────────────────────────────────────
create policy "skill links readable by authenticated"
  on profile_skills for select to authenticated using (true);
create policy "manage own skill links"
  on profile_skills for all to authenticated
  using (auth.uid() = profile_id) with check (auth.uid() = profile_id);

-- ── swipes (private to the swiper) ──────────────────────────────────────────
create policy "read own swipes"
  on swipes for select to authenticated using (auth.uid() = swiper_id);
create policy "insert own swipes"
  on swipes for insert to authenticated with check (auth.uid() = swiper_id);

-- ── matches (visible to both participants) ──────────────────────────────────
create policy "read own matches"
  on matches for select to authenticated
  using (auth.uid() in (user_a, user_b));

-- ── messages (only within your matches) ─────────────────────────────────────
create policy "read messages in own matches"
  on messages for select to authenticated
  using (is_match_participant(match_id));
create policy "send messages in own matches"
  on messages for insert to authenticated
  with check (auth.uid() = sender_id and is_match_participant(match_id));

-- ── collabs ─────────────────────────────────────────────────────────────────
create policy "read public or own collabs"
  on collabs for select to authenticated
  using (
    is_public
    or exists (
      select 1 from collab_members cm
      where cm.collab_id = collabs.id and cm.profile_id = auth.uid()
    )
  );
create policy "members manage collabs"
  on collabs for all to authenticated
  using (
    exists (
      select 1 from collab_members cm
      where cm.collab_id = collabs.id and cm.profile_id = auth.uid()
    )
  )
  with check (true);

create policy "read collab members"
  on collab_members for select to authenticated using (true);
create policy "manage own membership"
  on collab_members for all to authenticated
  using (auth.uid() = profile_id) with check (auth.uid() = profile_id);

-- ── feed_posts (public read, author writes) ─────────────────────────────────
create policy "feed readable by authenticated"
  on feed_posts for select to authenticated using (true);
create policy "author manages own posts"
  on feed_posts for all to authenticated
  using (auth.uid() = author_id) with check (auth.uid() = author_id);

-- ── behavioral_signals (private to owner) ───────────────────────────────────
create policy "own signals"
  on behavioral_signals for all to authenticated
  using (auth.uid() = profile_id) with check (auth.uid() = profile_id);

-- ── cosmetic_unlocks (owner reads) ──────────────────────────────────────────
create policy "read own unlocks"
  on cosmetic_unlocks for select to authenticated
  using (auth.uid() = profile_id);

-- ── safety_checkins (owner only) ────────────────────────────────────────────
create policy "own checkins"
  on safety_checkins for all to authenticated
  using (auth.uid() = profile_id) with check (auth.uid() = profile_id);
