-- Phase 3: collab XP dedup. Previously each logged collab re-awarded 18 XP per
-- tagged skill, so two colluding accounts could log unlimited collabs and grind
-- XP. Now a (member, skill, match) pair earns collab XP at most once — the event
-- ref is the match id, and we skip the award if such an event already exists.

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

  if p_skill_ids is not null then
    foreach v_skill in array p_skill_ids loop
      insert into collab_skills (collab_id, skill_id)
      values (v_collab, v_skill) on conflict do nothing;

      -- Award only if the member has the skill AND hasn't already earned collab
      -- XP for it on THIS match (ref = match id).
      if exists (select 1 from profile_skills
                 where profile_id = v_a and skill_id = v_skill)
         and not exists (select 1 from skill_events
                 where profile_id = v_a and skill_id = v_skill
                   and source = 'collab' and ref = p_match::text) then
        perform award_skill_xp(v_a, v_skill, 'collab', 18, p_match::text);
      end if;

      if exists (select 1 from profile_skills
                 where profile_id = v_b and skill_id = v_skill)
         and not exists (select 1 from skill_events
                 where profile_id = v_b and skill_id = v_skill
                   and source = 'collab' and ref = p_match::text) then
        perform award_skill_xp(v_b, v_skill, 'collab', 18, p_match::text);
      end if;
    end loop;
  end if;

  return v_collab;
end;
$$;
