-- FCM push: "someone needs your skill" — notify proven helpers when a new ask
-- is posted. Also switches the notify payload to a user_ids LIST so a fan-out to
-- many helpers is a single backend call (the endpoint loops).

-- Comment trigger: same behaviour, list payload.
create or replace function notify_on_comment()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare
  v_author uuid; v_title text; v_commenter text; v_url text; v_secret text;
begin
  select author_id, body into v_author, v_title
    from feed_posts where id = new.post_id;
  if v_author is null or v_author = new.author_id then
    return new;
  end if;
  select value into v_url    from app_config where key = 'notify_url';
  select value into v_secret from app_config where key = 'notify_secret';
  if v_url is null then return new; end if;
  select coalesce(display_name, '@' || username) into v_commenter
    from profiles where id = new.author_id;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json', 'x-notify-secret', coalesce(v_secret, '')),
    body := jsonb_build_object(
      'user_ids', jsonb_build_array(v_author),
      'title', 'New answer on your ask',
      'body', coalesce(v_commenter, 'Someone') || ' replied: ' ||
              left(coalesce(v_title, ''), 80),
      'data', jsonb_build_object('post_id', new.post_id::text)
    )
  );
  return new;
end;
$$;

-- New ask → notify the builders who've PROVEN one of its skills (capped, excl.
-- the author). Mirrors the get_asks_for_me routing (weight >= 0.4).
create or replace function notify_on_new_ask()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare v_url text; v_secret text; v_recipients jsonb;
begin
  if new.kind <> 'ask'
     or new.skill_tags is null
     or array_length(new.skill_tags, 1) is null then
    return new;
  end if;
  select value into v_url    from app_config where key = 'notify_url';
  select value into v_secret from app_config where key = 'notify_secret';
  if v_url is null then return new; end if;

  select jsonb_agg(uid) into v_recipients from (
    select distinct ps.profile_id as uid
    from unnest(new.skill_tags) as t(tag)
    join skills sk on lower(sk.name) = lower(t.tag)
    join profile_skills ps on ps.skill_id = sk.id and ps.weight >= 0.4
    where ps.profile_id <> new.author_id
    limit 25
  ) m;
  if v_recipients is null then return new; end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json', 'x-notify-secret', coalesce(v_secret, '')),
    body := jsonb_build_object(
      'user_ids', v_recipients,
      'title', 'Someone needs your skills',
      'body', left(coalesce(new.body, 'A builder posted an ask you can help with'), 80),
      'data', jsonb_build_object('post_id', new.id::text)
    )
  );
  return new;
end;
$$;

drop trigger if exists notify_new_ask on feed_posts;
create trigger notify_new_ask after insert on feed_posts
  for each row execute function notify_on_new_ask();
