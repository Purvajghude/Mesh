-- Make demo matching feel realistic. record_swipe auto-creates a reciprocal
-- match when you right-swipe a @mesh.demo seed user; it was 70% (felt like every
-- swipe). Drop it to 30% so matches are occasional, while still letting a demo
-- reliably reach the match overlay + AI pitches.

create or replace function record_swipe(
  p_target uuid, p_direction swipe_direction, p_time_ms integer default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  me uuid := auth.uid();
  reciprocal boolean := false;
  is_demo boolean;
  v_match uuid;
begin
  insert into swipes (swiper_id, target_id, direction, time_spent_ms)
  values (me, p_target, p_direction, p_time_ms)
  on conflict (swiper_id, target_id)
    do update set direction = excluded.direction, time_spent_ms = excluded.time_spent_ms;

  if p_direction in ('right', 'up') then
    select exists (
      select 1 from swipes
      where swiper_id = p_target and target_id = me and direction in ('right', 'up')
    ) into reciprocal;

    if not reciprocal then
      select exists (
        select 1 from auth.users where id = p_target and email like '%@mesh.demo'
      ) into is_demo;
      if is_demo and random() < 0.3 then
        insert into swipes (swiper_id, target_id, direction)
        values (p_target, me, 'right')
        on conflict (swiper_id, target_id) do nothing;
        reciprocal := true;
      end if;
    end if;

    if reciprocal then
      insert into matches (user_a, user_b)
      values (least(me, p_target), greatest(me, p_target))
      on conflict (user_a, user_b) do nothing;
      select id into v_match from matches
      where user_a = least(me, p_target) and user_b = greatest(me, p_target);
      return jsonb_build_object('matched', true, 'match_id', v_match);
    end if;
  end if;

  return jsonb_build_object('matched', false);
end;
$$;
