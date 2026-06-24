-- Infinite skills + the crafting tree.
--
-- Skills are an open vocabulary now: any skill can be added and is embedded on
-- the fly (backend POST /profile/skills), so the recommendation engine reasons
-- about it immediately. Combining two LEVELED skills crafts a higher-order
-- compound skill (Infinite-Craft style) — cached per pair so a combination is
-- deterministic and shared across users.

-- Allow manual self-adds and crafted skills as XP-event sources.
alter table skill_events drop constraint if exists skill_events_source_check;
alter table skill_events add constraint skill_events_source_check
  check (source in ('seed', 'collab', 'repo', 'cert', 'project', 'manual', 'craft'));

-- A crafting recipe: an unordered pair of skills → the compound they produce.
-- Convention: skill_a_id < skill_b_id (the backend normalizes order) so each
-- pair maps to exactly one result, like Infinite Craft's deterministic combos.
create table if not exists skill_recipes (
  skill_a_id      uuid not null references skills(id) on delete cascade,
  skill_b_id      uuid not null references skills(id) on delete cascade,
  result_skill_id uuid not null references skills(id) on delete cascade,
  created_at      timestamptz default now(),
  primary key (skill_a_id, skill_b_id)
);

-- Marks skills that are compounds (crafted), with an optional blurb explaining
-- what the combination represents.
alter table skills add column if not exists is_compound boolean not null default false;
alter table skills add column if not exists blurb text;
