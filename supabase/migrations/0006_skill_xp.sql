-- EXP / earned-expertise system.
--
-- A skill's proficiency is no longer self-declared — it is EARNED. skill_events
-- is an append-only ledger of XP grants (seed | collab | repo | cert | project).
-- Each (profile, skill) caches total xp + the derived proficiency weight on
-- profile_skills, which the recommendation engine already reads as proficiency.
-- This turns Mesh's skill graph into evidence-backed competence — the signal a
-- résumé can't give (and the data RedRob's HR intelligence wants).

alter table profile_skills
  add column if not exists xp numeric not null default 0;

create table if not exists skill_events (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references profiles(id) on delete cascade,
  skill_id    uuid not null references skills(id) on delete cascade,
  source      text not null
              check (source in ('seed', 'collab', 'repo', 'cert', 'project')),
  points      numeric not null,
  ref         text,
  created_at  timestamptz not null default now()
);
create index if not exists skill_events_profile_skill_idx
  on skill_events (profile_id, skill_id);

-- Proficiency curve: weight = ln(1+xp)/ln(101), capped at 1.0.
-- ~100 xp → 1.0, ~24 xp → 0.7, ~9 xp → 0.5. Diminishing returns, like real mastery.
create or replace function xp_to_weight(p_xp numeric)
returns numeric language sql immutable as $$
  select least(1.0, ln(1 + greatest(p_xp, 0)) / ln(101));
$$;

-- Award XP to a (profile, skill): append a ledger event, bump the cached xp, and
-- recompute the derived proficiency weight. Auto-creates the profile_skills row
-- if the user didn't already list the skill (i.e. earning a brand-new skill).
create or replace function award_skill_xp(
  p_profile uuid,
  p_skill   uuid,
  p_source  text,
  p_points  numeric,
  p_ref     text default null
) returns numeric
  language plpgsql security definer set search_path to 'public' as $$
declare
  v_xp numeric;
begin
  insert into skill_events (profile_id, skill_id, source, points, ref)
  values (p_profile, p_skill, p_source, p_points, p_ref);

  insert into profile_skills (profile_id, skill_id, source, weight, xp)
  values (p_profile, p_skill, 'manual', 0, 0)
  on conflict (profile_id, skill_id) do nothing;

  update profile_skills
     set xp = xp + p_points,
         weight = xp_to_weight(xp + p_points)
   where profile_id = p_profile and skill_id = p_skill
   returning xp into v_xp;

  return v_xp;
end;
$$;

-- Back-fill: convert today's self-declared weights into earned XP so the ledger
-- reproduces current proficiencies exactly (nothing in the recsys shifts).
insert into skill_events (profile_id, skill_id, source, points, ref)
select profile_id, skill_id, 'seed',
       round((exp(weight * ln(101)) - 1)::numeric, 2), 'initial'
from profile_skills
where xp = 0;

update profile_skills
   set xp = round((exp(weight * ln(101)) - 1)::numeric, 2)
 where xp = 0;
