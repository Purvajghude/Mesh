-- Close the EXP loop: logging a collab awards XP to each participant for the
-- skills they brought to it. This is what makes expertise *earned* — your
-- proficiency grows from real shipped work, not self-report.

create table if not exists collab_skills (
  collab_id uuid not null references collabs(id) on delete cascade,
  skill_id  uuid not null references skills(id) on delete cascade,
  primary key (collab_id, skill_id)
);

-- XP granted per skill per logged collab.
-- (Tunable — 18 takes a mid skill from ~L3 toward L4 over a couple collabs.)
create or replace function log_collab(
  p_match       uuid,
  p_title       text,
  p_description text default null,
  p_skill_ids   uuid[] default null
) returns uuid
  language plpgsql security definer set search_path to 'public' as $$
declare
  v_collab uuid;
  v_a uuid;
  v_b uuid;
  v_skill uuid;
begin
  if not is_match_participant(p_match) then
    raise exception 'not a participant in this match';
  end if;

  select user_a, user_b into v_a, v_b from matches where id = p_match;

  insert into collabs (match_id, title, description, status)
  values (p_match, p_title, p_description, 'active')
  returning id into v_collab;

  insert into collab_members (collab_id, profile_id)
  values (v_collab, v_a), (v_collab, v_b);

  update profiles set collab_count = collab_count + 1
  where id in (v_a, v_b);

  -- Award XP for each tagged skill — but only to a member who actually has
  -- that skill (you level up in what you brought, not what your partner did).
  if p_skill_ids is not null then
    foreach v_skill in array p_skill_ids loop
      insert into collab_skills (collab_id, skill_id)
      values (v_collab, v_skill) on conflict do nothing;

      if exists (select 1 from profile_skills
                 where profile_id = v_a and skill_id = v_skill) then
        perform award_skill_xp(v_a, v_skill, 'collab', 18, p_title);
      end if;
      if exists (select 1 from profile_skills
                 where profile_id = v_b and skill_id = v_skill) then
        perform award_skill_xp(v_b, v_skill, 'collab', 18, p_title);
      end if;
    end loop;
  end if;

  return v_collab;
end;
$$;

-- The skills a collab can be tagged with: the union of both participants'
-- skills. SECURITY DEFINER so a participant can read the other's skill names.
create or replace function collab_skill_options(p_match uuid)
returns table (id uuid, name text)
  language sql security definer set search_path to 'public' as $$
  select distinct s.id, s.name
  from matches m
  join profile_skills ps on ps.profile_id in (m.user_a, m.user_b)
  join skills s on s.id = ps.skill_id
  where m.id = p_match and is_match_participant(p_match)
  order by s.name;
$$;
