-- FCM push Stage 2: fire a notification when an ask gets answered.
--
-- On a new comment, a trigger calls the backend /internal/notify via pg_net,
-- which sends FCM to the post author's devices. The backend URL + shared secret
-- live in app_config (inserted out-of-band, NOT committed, so the secret stays
-- out of git). app_config is service/definer-only (RLS on, no policies).

create extension if not exists pg_net;

create table if not exists app_config (
  key   text primary key,
  value text
);
alter table app_config enable row level security;  -- no policies → not client-readable

create or replace function notify_on_comment()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  v_author uuid; v_title text; v_commenter text; v_url text; v_secret text;
begin
  select author_id, body into v_author, v_title
    from feed_posts where id = new.post_id;
  -- only notify the asker, and never for their own comment
  if v_author is null or v_author = new.author_id then
    return new;
  end if;

  select value into v_url    from app_config where key = 'notify_url';
  select value into v_secret from app_config where key = 'notify_secret';
  if v_url is null then return new; end if;  -- not configured yet → no-op

  select coalesce(display_name, '@' || username) into v_commenter
    from profiles where id = new.author_id;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-notify-secret', coalesce(v_secret, '')
    ),
    body := jsonb_build_object(
      'user_id', v_author,
      'title', 'New answer on your ask',
      'body', coalesce(v_commenter, 'Someone') || ' replied: ' ||
              left(coalesce(v_title, ''), 80)
    )
  );
  return new;
end;
$$;

drop trigger if exists notify_comment on feed_comments;
create trigger notify_comment after insert on feed_comments
  for each row execute function notify_on_comment();
