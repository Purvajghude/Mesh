-- Connected accounts → proof-of-skill XP.
--
-- Mesh aggregates *verifiable* competence from a builder's external footprint
-- (GitHub now; Codeforces / LeetCode / Chess.com / Strava etc. slot in via the
-- same framework). Connecting an account fetches public stats and awards XP to
-- the relevant skills — evidence-backed expertise, the RedRob data flywheel.

alter table skill_events drop constraint if exists skill_events_source_check;
alter table skill_events add constraint skill_events_source_check
  check (source in (
    'seed', 'collab', 'repo', 'cert', 'project', 'manual', 'craft', 'integration'
  ));

create table if not exists connected_accounts (
  id             uuid primary key default gen_random_uuid(),
  profile_id     uuid not null references profiles(id) on delete cascade,
  provider       text not null,
  handle         text not null,
  stats          jsonb not null default '{}'::jsonb,   -- raw fetched stats
  granted_xp     jsonb not null default '{}'::jsonb,   -- {skill_name: xp} we've awarded
  connected_at   timestamptz not null default now(),
  last_synced_at timestamptz not null default now(),
  unique (profile_id, provider)
);
