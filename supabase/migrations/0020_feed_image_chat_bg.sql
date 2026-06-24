-- Media uploads: images on feed posts + custom chat backgrounds.

-- A feed post can carry one image (uploaded to the public 'portfolio' bucket).
alter table feed_posts add column if not exists image_url text;

-- A user can set a custom uploaded chat background. When chat_bg = 'custom',
-- chat_bg_url points at the uploaded image (in the public 'chat-media' bucket).
alter table profiles add column if not exists chat_bg_url text;

-- get_feed must now surface image_url. The return type changes, so drop+recreate.
drop function if exists get_feed(text, integer);
create or replace function get_feed(p_channel text default null, p_limit integer default 50)
returns table(
  id uuid, channel text, body text, image_url text, upvotes integer,
  created_at timestamptz, username text, display_name text,
  avatar_config jsonb, upvoted boolean
) language sql stable security definer set search_path to 'public' as $$
  select
    fp.id, fp.channel, fp.body, fp.image_url, fp.upvotes, fp.created_at,
    author.username, author.display_name, author.avatar_config,
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
