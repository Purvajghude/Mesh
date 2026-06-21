-- Mesh — initial schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query).
-- Idempotent where practical so it can be re-run safely during development.

-- ───────────────────────────────────────────────────────────────────────────
-- Extensions
-- ───────────────────────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "vector";      -- pgvector for skill embeddings

-- ───────────────────────────────────────────────────────────────────────────
-- Enums
-- ───────────────────────────────────────────────────────────────────────────
do $$ begin
  create type swipe_direction as enum ('left', 'right', 'up');
exception when duplicate_object then null; end $$;

do $$ begin
  create type skill_source as enum ('github', 'linkedin', 'resume', 'manual');
exception when duplicate_object then null; end $$;

do $$ begin
  create type collab_status as enum ('proposed', 'active', 'completed', 'cancelled');
exception when duplicate_object then null; end $$;

-- ───────────────────────────────────────────────────────────────────────────
-- profiles — one row per auth user (no real photos; avatar is config-driven)
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  username        text unique not null,
  display_name    text,
  vibe_statement  text,                         -- short "what I love building"
  avatar_config   jsonb not null default '{}',  -- avatar part selections
  reputation      numeric not null default 5.0, -- 0..5, peer-reviewed
  collab_count    int not null default 0,
  is_verified     bool not null default false,
  -- 384-dim embedding from sentence-transformers (all-MiniLM-L6-v2)
  skill_embedding vector(384),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- skills — normalized skill catalog + per-user join
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists skills (
  id        uuid primary key default gen_random_uuid(),
  name      text unique not null,
  category  text                                  -- e.g. 'dev', 'design', 'craft'
);

create table if not exists profile_skills (
  profile_id  uuid not null references profiles(id) on delete cascade,
  skill_id    uuid not null references skills(id) on delete cascade,
  source      skill_source not null default 'manual',
  verified    bool not null default false,
  weight      numeric not null default 1.0,       -- proficiency / confidence
  primary key (profile_id, skill_id)
);

-- ───────────────────────────────────────────────────────────────────────────
-- swipes — every decision, with the implicit signal we feed the model
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists swipes (
  id            uuid primary key default gen_random_uuid(),
  swiper_id     uuid not null references profiles(id) on delete cascade,
  target_id     uuid not null references profiles(id) on delete cascade,
  direction     swipe_direction not null,
  time_spent_ms int,                              -- dwell time before deciding
  created_at    timestamptz not null default now(),
  unique (swiper_id, target_id)
);

-- ───────────────────────────────────────────────────────────────────────────
-- matches — created when two users right-swipe each other
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists matches (
  id          uuid primary key default gen_random_uuid(),
  user_a      uuid not null references profiles(id) on delete cascade,
  user_b      uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  -- store the pair canonically (a < b) so the unique constraint dedupes
  check (user_a < user_b),
  unique (user_a, user_b)
);

-- ───────────────────────────────────────────────────────────────────────────
-- messages — realtime chat, only between matched users
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists messages (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid not null references matches(id) on delete cascade,
  sender_id   uuid not null references profiles(id) on delete cascade,
  body        text not null,
  flagged     bool not null default false,        -- safety auto-flag
  created_at  timestamptz not null default now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- collabs — logged projects between matched users
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists collabs (
  id            uuid primary key default gen_random_uuid(),
  match_id      uuid references matches(id) on delete set null,
  title         text not null,
  description   text,
  status        collab_status not null default 'proposed',
  is_public     bool not null default false,
  created_at    timestamptz not null default now(),
  completed_at  timestamptz
);

create table if not exists collab_members (
  collab_id   uuid not null references collabs(id) on delete cascade,
  profile_id  uuid not null references profiles(id) on delete cascade,
  rating      int,                                -- peer review after completion
  primary key (collab_id, profile_id)
);

-- ───────────────────────────────────────────────────────────────────────────
-- feed_posts — Reddit-style community feed of successful collabs
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists feed_posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references profiles(id) on delete cascade,
  collab_id   uuid references collabs(id) on delete set null,
  channel     text not null default 'general',    -- e.g. 'web-dev', 'music'
  body        text not null,
  upvotes     int not null default 0,
  created_at  timestamptz not null default now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- behavioral_signals — raw implicit-feedback event log for the AI engine
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists behavioral_signals (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references profiles(id) on delete cascade,
  event_type  text not null,                      -- 'card_dwell','skill_tap',...
  payload     jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- cosmetic_unlocks — gacha reward history (avatar parts, frames, badges)
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists cosmetic_unlocks (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references profiles(id) on delete cascade,
  item_key    text not null,
  rarity      text not null default 'common',     -- common..legendary
  unlocked_at timestamptz not null default now(),
  unique (profile_id, item_key)
);

-- ───────────────────────────────────────────────────────────────────────────
-- safety_checkins — meetup safety net
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists safety_checkins (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references profiles(id) on delete cascade,
  contact_info  text,                             -- trusted contact
  meetup_at     timestamptz,
  checked_in    bool not null default false,
  created_at    timestamptz not null default now()
);

-- ───────────────────────────────────────────────────────────────────────────
-- Indexes
-- ───────────────────────────────────────────────────────────────────────────
create index if not exists idx_swipes_target on swipes(target_id);
create index if not exists idx_messages_match on messages(match_id);
create index if not exists idx_feed_channel on feed_posts(channel, created_at desc);
create index if not exists idx_signals_profile on behavioral_signals(profile_id, created_at desc);

-- Approximate-nearest-neighbour index for skill similarity search.
create index if not exists idx_profiles_embedding
  on profiles using ivfflat (skill_embedding vector_cosine_ops)
  with (lists = 100);
