-- Phase 6: safety — report, block, and anti-spam.
--
-- Real strangers + user content means report/block must be first-class. Reports
-- auto-hide content past a threshold; blocks hide a person both ways, enforced
-- SERVER-SIDE inside the reader functions (a client can't opt out). Plus gentle
-- per-user write rate limits so one account can't flood the feed.

create table if not exists content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'comment', 'user')),
  target_id   uuid not null,
  reason      text,
  created_at  timestamptz not null default now(),
  unique (reporter_id, target_type, target_id)   -- one report per user per target
);
create index if not exists idx_reports_target on content_reports(target_type, target_id);

create table if not exists user_blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table feed_posts    add column if not exists report_count int not null default 0;
alter table feed_comments add column if not exists report_count int not null default 0;

alter table content_reports enable row level security;
alter table user_blocks     enable row level security;
-- Reports: write-only via RPC, no client read. Blocks: you can read your own.
drop policy if exists "blocks owner read" on user_blocks;
create policy "blocks owner read" on user_blocks
  for select to authenticated using (blocker_id = auth.uid());

-- Are I and p_other blocked in either direction? (used to filter everything)
create or replace function is_blocked(p_other uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from user_blocks
    where (blocker_id = auth.uid() and blocked_id = p_other)
       or (blocker_id = p_other and blocked_id = auth.uid())
  );
$$;
grant execute on function is_blocked(uuid) to authenticated;

create or replace function report_content(p_type text, p_id uuid, p_reason text default null)
returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not authenticated'; end if;
  if p_type not in ('post', 'comment', 'user') then raise exception 'bad target'; end if;
  insert into content_reports (reporter_id, target_type, target_id, reason)
    values (me, p_type, p_id, nullif(btrim(coalesce(p_reason, '')), ''))
    on conflict (reporter_id, target_type, target_id) do nothing;
  -- Recompute the count (idempotent) and auto-hide past the threshold.
  if p_type = 'post' then
    update feed_posts
      set report_count = (select count(*) from content_reports
                          where target_type = 'post' and target_id = p_id)
      where id = p_id;
    update feed_posts set flagged = true where id = p_id and report_count >= 3;
  elsif p_type = 'comment' then
    update feed_comments
      set report_count = (select count(*) from content_reports
                          where target_type = 'comment' and target_id = p_id)
      where id = p_id;
  end if;
end;
$$;

create or replace function block_user(p_target uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_target = auth.uid() then raise exception 'you cannot block yourself'; end if;
  insert into user_blocks (blocker_id, blocked_id)
    values (auth.uid(), p_target) on conflict do nothing;
end;
$$;

create or replace function unblock_user(p_target uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  delete from user_blocks where blocker_id = auth.uid() and blocked_id = p_target;
end;
$$;

-- ── Readers re-created with block + report filtering ─────────────────────────

create or replace function get_feed(p_channel text default null, p_limit integer default 50)
returns table(
  id uuid, channel text, kind text, body text, image_url text,
  skill_tags text[], status text, upvotes integer, comment_count integer,
  ai_answer text, flagged boolean, match_score integer,
  created_at timestamptz, username text, display_name text, avatar_config jsonb,
  author_id uuid, upvoted boolean
) language sql stable security definer set search_path to 'public' as $$
  select
    fp.id, fp.channel, fp.kind, fp.body, fp.image_url,
    fp.skill_tags, fp.status, fp.upvotes, fp.comment_count,
    fp.ai_answer, fp.flagged,
    coalesce((select count(*)::int from unnest(fp.skill_tags) as t(tag)
      join skills sk on lower(sk.name) = lower(t.tag)
      join profile_skills ps on ps.skill_id = sk.id
        and ps.profile_id = auth.uid() and ps.weight >= 0.4), 0) as match_score,
    fp.created_at,
    author.username, author.display_name, author.avatar_config, fp.author_id,
    exists (select 1 from feed_post_votes v
            where v.post_id = fp.id and v.profile_id = auth.uid()) as upvoted
  from feed_posts fp
  join profiles author on author.id = fp.author_id
  where (p_channel is null or fp.channel = p_channel)
    and not fp.flagged
    and not is_blocked(fp.author_id)
  order by fp.created_at desc
  limit p_limit;
$$;

create or replace function get_asks_for_me(p_limit integer default 20)
returns table(
  id uuid, channel text, kind text, body text, image_url text,
  skill_tags text[], status text, upvotes integer, comment_count integer,
  ai_answer text, flagged boolean, match_score integer,
  created_at timestamptz, username text, display_name text, avatar_config jsonb,
  author_id uuid, upvoted boolean
) language sql stable security definer set search_path to 'public' as $$
  select
    fp.id, fp.channel, fp.kind, fp.body, fp.image_url,
    fp.skill_tags, fp.status, fp.upvotes, fp.comment_count, fp.ai_answer, fp.flagged,
    (select count(*)::int from unnest(fp.skill_tags) as t(tag)
       join skills sk on lower(sk.name) = lower(t.tag)
       join profile_skills ps on ps.skill_id = sk.id
         and ps.profile_id = auth.uid() and ps.weight >= 0.4) as match_score,
    fp.created_at,
    author.username, author.display_name, author.avatar_config, fp.author_id,
    exists (select 1 from feed_post_votes v
            where v.post_id = fp.id and v.profile_id = auth.uid()) as upvoted
  from feed_posts fp
  join profiles author on author.id = fp.author_id
  where fp.kind = 'ask' and fp.status in ('open', 'answered')
    and not fp.flagged and fp.author_id <> auth.uid()
    and not is_blocked(fp.author_id)
    and exists (select 1 from unnest(fp.skill_tags) as t(tag)
      join skills sk on lower(sk.name) = lower(t.tag)
      join profile_skills ps on ps.skill_id = sk.id
        and ps.profile_id = auth.uid() and ps.weight >= 0.4)
  order by match_score desc, fp.created_at desc
  limit p_limit;
$$;

create or replace function get_post_comments(p_post uuid)
returns table(
  id uuid, body text, created_at timestamptz,
  author_id uuid, username text, display_name text, avatar_config jsonb
) language sql stable security definer set search_path to 'public' as $$
  select c.id, c.body, c.created_at, c.author_id,
         p.username, p.display_name, p.avatar_config
  from feed_comments c
  join profiles p on p.id = c.author_id
  where c.post_id = p_post
    and c.report_count < 3
    and not is_blocked(c.author_id)
  order by c.created_at asc;
$$;

create or replace function search_profiles(p_query text, p_limit integer default 30)
returns table(
  id uuid, username text, display_name text, avatar_config jsonb,
  help_karma integer, helps_count integer, matched_skill text
) language sql stable security definer set search_path to 'public' as $$
  select p.id, p.username, p.display_name, p.avatar_config,
    p.help_karma, p.helps_count,
    (select sk.name from profile_skills ps join skills sk on sk.id = ps.skill_id
       where ps.profile_id = p.id and sk.name ilike '%' || p_query || '%'
       order by ps.weight desc limit 1) as matched_skill
  from profiles p
  where p.id <> auth.uid() and p.onboarded
    and length(coalesce(p_query, '')) >= 2
    and not is_blocked(p.id)
    and (p.username ilike '%' || p_query || '%'
      or p.display_name ilike '%' || p_query || '%'
      or exists (select 1 from profile_skills ps join skills sk on sk.id = ps.skill_id
                 where ps.profile_id = p.id and sk.name ilike '%' || p_query || '%'))
  order by p.help_karma desc, p.reputation desc
  limit p_limit;
$$;

-- ── Anti-spam: gentle per-user write rate limits ─────────────────────────────
create or replace function rl_check()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  if tg_table_name = 'feed_posts' then
    if (select count(*) from feed_posts
        where author_id = new.author_id and created_at > now() - interval '1 hour') >= 20 then
      raise exception 'you''re posting too fast — take a short break';
    end if;
  elsif tg_table_name = 'feed_comments' then
    if (select count(*) from feed_comments
        where author_id = new.author_id and created_at > now() - interval '1 hour') >= 40 then
      raise exception 'you''re commenting too fast — take a short break';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists rl_feed_posts on feed_posts;
create trigger rl_feed_posts before insert on feed_posts
  for each row execute function rl_check();
drop trigger if exists rl_feed_comments on feed_comments;
create trigger rl_feed_comments before insert on feed_comments
  for each row execute function rl_check();

revoke all on function report_content(text, uuid, text) from anon;
revoke all on function block_user(uuid) from anon;
revoke all on function unblock_user(uuid) from anon;
grant execute on function report_content(text, uuid, text) to authenticated;
grant execute on function block_user(uuid) to authenticated;
grant execute on function unblock_user(uuid) to authenticated;
