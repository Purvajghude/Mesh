-- Phase 2: post detail + threaded comments + ask resolution.
--
-- Comments are how help actually happens on an ask (answers = comments). The
-- asker marks the comment that solved it → status 'solved', solved_by set. That
-- resolution event is what Phase 4 reputation will be built on.

create table if not exists feed_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references feed_posts(id) on delete cascade,
  author_id  uuid not null references profiles(id) on delete cascade,
  parent_id  uuid references feed_comments(id) on delete cascade,  -- future nesting
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_feed_comments_post on feed_comments(post_id, created_at);

alter table feed_posts add column if not exists comment_count int not null default 0;

alter table feed_comments enable row level security;
drop policy if exists "comments readable" on feed_comments;
create policy "comments readable" on feed_comments
  for select to authenticated using (true);
drop policy if exists "delete own comments" on feed_comments;
create policy "delete own comments" on feed_comments
  for delete to authenticated using (author_id = auth.uid());
-- inserts go through add_comment() (SECURITY DEFINER) so count + status stay in sync.

create or replace function add_comment(p_post uuid, p_body text)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); v_id uuid; v_kind text; v_status text; v_author uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if coalesce(btrim(p_body), '') = '' then raise exception 'comment cannot be empty'; end if;
  select kind, status, author_id into v_kind, v_status, v_author
    from feed_posts where id = p_post;
  if not found then raise exception 'post not found'; end if;
  insert into feed_comments (post_id, author_id, body)
    values (p_post, me, btrim(p_body)) returning id into v_id;
  update feed_posts set comment_count = comment_count + 1 where id = p_post;
  -- an open ask that gets its first reply from someone else → "answered"
  if v_kind = 'ask' and v_status = 'open' and me <> v_author then
    update feed_posts set status = 'answered' where id = p_post;
  end if;
  return v_id;
end;
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
  order by c.created_at asc;
$$;

create or replace function mark_ask_solved(p_post uuid, p_comment uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); v_author uuid; v_kind text; v_solver uuid;
begin
  select author_id, kind into v_author, v_kind from feed_posts where id = p_post;
  if not found then raise exception 'post not found'; end if;
  if v_author <> me then raise exception 'only the asker can mark this solved'; end if;
  if v_kind <> 'ask' then raise exception 'only asks can be solved'; end if;
  select author_id into v_solver from feed_comments
    where id = p_comment and post_id = p_post;
  if not found then raise exception 'comment not found'; end if;
  update feed_posts
    set status = 'solved', solved_by = v_solver, solved_at = now()
    where id = p_post;
end;
$$;

-- get_feed must now surface comment_count. Return type changes → drop+recreate.
drop function if exists get_feed(text, integer);
create or replace function get_feed(p_channel text default null, p_limit integer default 50)
returns table(
  id uuid, channel text, kind text, body text, image_url text,
  skill_tags text[], status text, upvotes integer, comment_count integer,
  created_at timestamptz, username text, display_name text, avatar_config jsonb,
  author_id uuid, upvoted boolean
) language sql stable security definer set search_path to 'public' as $$
  select
    fp.id, fp.channel, fp.kind, fp.body, fp.image_url,
    fp.skill_tags, fp.status, fp.upvotes, fp.comment_count, fp.created_at,
    author.username, author.display_name, author.avatar_config, fp.author_id,
    exists (
      select 1 from feed_post_votes v
      where v.post_id = fp.id and v.profile_id = auth.uid()
    ) as upvoted
  from feed_posts fp
  join profiles author on author.id = fp.author_id
  where p_channel is null or fp.channel = p_channel
  order by fp.created_at desc
  limit p_limit;
$$;

revoke all on function add_comment(uuid, text) from anon;
revoke all on function get_post_comments(uuid) from anon;
revoke all on function mark_ask_solved(uuid, uuid) from anon;
revoke all on function get_feed(text, integer) from anon;
grant execute on function add_comment(uuid, text) to authenticated;
grant execute on function get_post_comments(uuid) to authenticated;
grant execute on function mark_ask_solved(uuid, uuid) to authenticated;
grant execute on function get_feed(text, integer) to authenticated;
