-- Phase 1 of the feed-of-helpers pivot: typed posts.
--
-- A feed post is now one of four kinds — ask (a blocker), show (shipped work),
-- offer (a helper advertising capacity), or buildlog (a progress update). Asks
-- carry a resolution status so "get unblocked" lives inside the feed (the old
-- separate help-board dissolves into this). skill_tags drive future routing.

alter table feed_posts add column if not exists kind text not null default 'show'
  check (kind in ('ask', 'show', 'offer', 'buildlog'));
alter table feed_posts add column if not exists skill_tags text[] not null default '{}';
-- status is only meaningful for asks: open → answered → solved (null otherwise).
alter table feed_posts add column if not exists status text
  check (status is null or status in ('open', 'answered', 'solved'));
alter table feed_posts add column if not exists solved_by uuid
  references profiles(id) on delete set null;
alter table feed_posts add column if not exists solved_at timestamptz;

create index if not exists idx_feed_kind on feed_posts(kind, created_at desc);

-- get_feed now surfaces kind / tags / status / author_id. Return type changes,
-- so drop + recreate.
drop function if exists get_feed(text, integer);
create or replace function get_feed(p_channel text default null, p_limit integer default 50)
returns table(
  id uuid, channel text, kind text, body text, image_url text,
  skill_tags text[], status text, upvotes integer, created_at timestamptz,
  username text, display_name text, avatar_config jsonb,
  author_id uuid, upvoted boolean
) language sql stable security definer set search_path to 'public' as $$
  select
    fp.id, fp.channel, fp.kind, fp.body, fp.image_url,
    fp.skill_tags, fp.status, fp.upvotes, fp.created_at,
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
grant execute on function get_feed(text, integer) to authenticated;
revoke all on function get_feed(text, integer) from anon;
