-- Phase 3: competence routing + AI assist fields.
--
-- Routing is done in SQL against the existing skill graph (post.skill_tags ↔ the
-- caller's proven skills), so the feed stays fast and backend-independent. The
-- AI fields (ai_answer, quality/flagged) are filled best-effort by the backend.

alter table feed_posts add column if not exists ai_answer text;        -- AI first-pass on an ask
alter table feed_posts add column if not exists quality numeric;       -- 0..1 moderation score (null = unmoderated)
alter table feed_posts add column if not exists flagged boolean not null default false;

-- get_feed: hide flagged posts, and tell the caller how well each post matches
-- their proven skills (match_score) + surface the AI first-pass + flag.
drop function if exists get_feed(text, integer);
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
    coalesce((
      select count(*)::int
      from unnest(fp.skill_tags) as t(tag)
      join skills sk on lower(sk.name) = lower(t.tag)
      join profile_skills ps on ps.skill_id = sk.id
        and ps.profile_id = auth.uid() and ps.weight >= 0.4
    ), 0) as match_score,
    fp.created_at,
    author.username, author.display_name, author.avatar_config, fp.author_id,
    exists (
      select 1 from feed_post_votes v
      where v.post_id = fp.id and v.profile_id = auth.uid()
    ) as upvoted
  from feed_posts fp
  join profiles author on author.id = fp.author_id
  where (p_channel is null or fp.channel = p_channel)
    and not fp.flagged
  order by fp.created_at desc
  limit p_limit;
$$;

-- Open asks routed to YOU — those needing a skill you've proven, best match first.
-- Powers the "asks match your skills" strip. Same column shape as get_feed.
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
    fp.skill_tags, fp.status, fp.upvotes, fp.comment_count,
    fp.ai_answer, fp.flagged,
    (select count(*)::int
       from unnest(fp.skill_tags) as t(tag)
       join skills sk on lower(sk.name) = lower(t.tag)
       join profile_skills ps on ps.skill_id = sk.id
         and ps.profile_id = auth.uid() and ps.weight >= 0.4) as match_score,
    fp.created_at,
    author.username, author.display_name, author.avatar_config, fp.author_id,
    exists (select 1 from feed_post_votes v
            where v.post_id = fp.id and v.profile_id = auth.uid()) as upvoted
  from feed_posts fp
  join profiles author on author.id = fp.author_id
  where fp.kind = 'ask'
    and fp.status in ('open', 'answered')
    and not fp.flagged
    and fp.author_id <> auth.uid()
    and exists (
      select 1
      from unnest(fp.skill_tags) as t(tag)
      join skills sk on lower(sk.name) = lower(t.tag)
      join profile_skills ps on ps.skill_id = sk.id
        and ps.profile_id = auth.uid() and ps.weight >= 0.4
    )
  order by match_score desc, fp.created_at desc
  limit p_limit;
$$;

revoke all on function get_feed(text, integer) from anon;
revoke all on function get_asks_for_me(integer) from anon;
grant execute on function get_feed(text, integer) to authenticated;
grant execute on function get_asks_for_me(integer) to authenticated;
