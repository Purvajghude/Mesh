-- Phase 4: reputation — "helpers are heroes".
--
-- Solving an ask earns the solver per-skill HELP-KARMA (in the ask's skill_tags).
-- Karma is *earned only when a different user (the asker) confirms* — you can't
-- self-award — and repeated solves between the same pair earn less (pair-damping),
-- which kills the obvious farming vectors. Per-skill karma → "Expert in X" badges
-- and leaderboards (the status game that keeps strong helpers showing up).

-- Append-only event log (private — read via SECURITY DEFINER functions only).
create table if not exists help_events (
  id         uuid primary key default gen_random_uuid(),
  helper_id  uuid not null references profiles(id) on delete cascade,
  asker_id   uuid not null references profiles(id) on delete cascade,
  post_id    uuid references feed_posts(id) on delete set null,
  skill_id   uuid references skills(id) on delete set null,
  points     int  not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_help_events_helper on help_events(helper_id, created_at desc);

-- Per-(profile, skill) karma cache (the reputation, derived from the events).
create table if not exists help_karma (
  profile_id uuid not null references profiles(id) on delete cascade,
  skill_id   uuid not null references skills(id) on delete cascade,
  karma int not null default 0,
  helps int not null default 0,
  primary key (profile_id, skill_id)
);
create index if not exists idx_help_karma_skill on help_karma(skill_id, karma desc);

alter table profiles add column if not exists help_karma  int not null default 0;
alter table profiles add column if not exists helps_count int not null default 0;

-- Both tables: writes via the SECURITY DEFINER functions only; no client policies
-- (reputation is surfaced through shaped reader functions, not raw rows).
alter table help_events enable row level security;
alter table help_karma  enable row level security;

-- Solving an ask now also awards reputation.
create or replace function mark_ask_solved(p_post uuid, p_comment uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare
  me uuid := auth.uid();
  v_author uuid; v_kind text; v_status text; v_solver uuid; v_tags text[];
  v_points int; v_prior int; v_skill uuid; t text;
begin
  select author_id, kind, status, skill_tags
    into v_author, v_kind, v_status, v_tags
    from feed_posts where id = p_post;
  if not found then raise exception 'post not found'; end if;
  if v_author <> me then raise exception 'only the asker can mark this solved'; end if;
  if v_kind <> 'ask' then raise exception 'only asks can be solved'; end if;
  if v_status = 'solved' then raise exception 'this ask is already solved'; end if;

  select author_id into v_solver from feed_comments
    where id = p_comment and post_id = p_post;
  if not found then raise exception 'comment not found'; end if;

  update feed_posts
    set status = 'solved', solved_by = v_solver, solved_at = now()
    where id = p_post;

  -- Never credit the asker for "solving" their own ask.
  if v_solver <> me then
    -- Pair-damping: the first solve between this asker→helper pair is worth
    -- full; repeats earn a fraction (kills reciprocal credit farming).
    select count(distinct post_id) into v_prior
      from help_events where helper_id = v_solver and asker_id = me;
    v_points := case when v_prior = 0 then 10 else 3 end;

    update profiles
      set help_karma = help_karma + v_points, helps_count = helps_count + 1
      where id = v_solver;

    if v_tags is null or array_length(v_tags, 1) is null then
      insert into help_events (helper_id, asker_id, post_id, skill_id, points)
        values (v_solver, me, p_post, null, v_points);
    else
      foreach t in array v_tags loop
        select id into v_skill from skills where lower(name) = lower(t) limit 1;
        if v_skill is not null then
          insert into help_events (helper_id, asker_id, post_id, skill_id, points)
            values (v_solver, me, p_post, v_skill, v_points);
          insert into help_karma (profile_id, skill_id, karma, helps)
            values (v_solver, v_skill, v_points, 1)
            on conflict (profile_id, skill_id)
            do update set karma = help_karma.karma + v_points,
                          helps = help_karma.helps + 1;
        end if;
      end loop;
    end if;
  end if;
end;
$$;

-- A user's helping reputation, per skill (powers expert badges on profiles).
-- karma >= 30 (~3 quality solves) reads as "Expert in X".
create or replace function get_help_profile(p_user uuid)
returns table(skill_id uuid, skill_name text, karma int, helps int, expert boolean)
language sql stable security definer set search_path to 'public' as $$
  select hk.skill_id, sk.name, hk.karma, hk.helps, (hk.karma >= 30)
  from help_karma hk
  join skills sk on sk.id = hk.skill_id
  where hk.profile_id = p_user and hk.karma > 0
  order by hk.karma desc;
$$;

-- Top helpers overall (p_skill null) or within one skill — the leaderboard.
create or replace function get_top_helpers(p_skill text default null, p_limit integer default 20)
returns table(
  profile_id uuid, username text, display_name text, avatar_config jsonb,
  karma integer, helps integer
) language sql stable security definer set search_path to 'public' as $$
  select p.id, p.username, p.display_name, p.avatar_config,
         p.help_karma as karma, p.helps_count as helps
  from profiles p
  where p_skill is null and p.help_karma > 0
  union all
  select p.id, p.username, p.display_name, p.avatar_config, hk.karma, hk.helps
  from help_karma hk
  join profiles p on p.id = hk.profile_id
  join skills sk on sk.id = hk.skill_id
  where p_skill is not null and lower(sk.name) = lower(p_skill) and hk.karma > 0
  order by karma desc
  limit p_limit;
$$;

revoke all on function get_help_profile(uuid) from anon;
revoke all on function get_top_helpers(text, integer) from anon;
grant execute on function get_help_profile(uuid) to authenticated;
grant execute on function get_top_helpers(text, integer) to authenticated;
