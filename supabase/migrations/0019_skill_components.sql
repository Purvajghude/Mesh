-- Skill components + multi-ingredient crafting.
--
-- skill_components records the atomic skills a compound was crafted from. It
-- powers the drill-down ("what is Web Architecture made of?") and lets crafting
-- combine MORE THAN TWO skills (the old skill_recipes is a 2-skill-only pair).

create table if not exists skill_components (
  compound_skill_id  uuid not null references skills(id) on delete cascade,
  component_skill_id uuid not null references skills(id) on delete cascade,
  primary key (compound_skill_id, component_skill_id)
);

-- Multi-ingredient recipe cache, keyed by a canonical signature (sorted component
-- ids joined by '+') so any unordered combination maps to exactly one compound.
create table if not exists skill_recipes_multi (
  signature       text primary key,
  result_skill_id uuid not null references skills(id) on delete cascade,
  created_at      timestamptz default now()
);

-- Backfill components from the existing pairwise recipes so compounds crafted
-- before this table still show their parts.
insert into skill_components (compound_skill_id, component_skill_id)
  select result_skill_id, skill_a_id from skill_recipes
  union
  select result_skill_id, skill_b_id from skill_recipes
on conflict do nothing;

-- Backfill the multi-recipe cache from pairwise recipes too.
insert into skill_recipes_multi (signature, result_skill_id)
  select case when skill_a_id::text < skill_b_id::text
              then skill_a_id::text || '+' || skill_b_id::text
              else skill_b_id::text || '+' || skill_a_id::text end,
         result_skill_id
  from skill_recipes
on conflict (signature) do nothing;

-- These are global skill-graph tables (non-sensitive); writes are backend-only
-- (service role). Keep RLS on with a read policy so no table is left RLS-off.
alter table skill_components    enable row level security;
alter table skill_recipes_multi enable row level security;

drop policy if exists "components read" on skill_components;
create policy "components read" on skill_components for select to authenticated using (true);

drop policy if exists "recipes_multi read" on skill_recipes_multi;
create policy "recipes_multi read" on skill_recipes_multi for select to authenticated using (true);
