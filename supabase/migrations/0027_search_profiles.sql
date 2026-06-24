-- Phase 5: builder search (closes "search someone by username" + skill discovery).
--
-- Matches on username, display name, OR a skill the person has — so "@purvaj"
-- and "react" both work. Strong helpers (help_karma) surface first. Returns the
-- matched skill as the "why". SECURITY DEFINER to read others' public cards.

create or replace function search_profiles(p_query text, p_limit integer default 30)
returns table(
  id uuid, username text, display_name text, avatar_config jsonb,
  help_karma integer, helps_count integer, matched_skill text
) language sql stable security definer set search_path to 'public' as $$
  select
    p.id, p.username, p.display_name, p.avatar_config,
    p.help_karma, p.helps_count,
    (select sk.name
       from profile_skills ps join skills sk on sk.id = ps.skill_id
       where ps.profile_id = p.id and sk.name ilike '%' || p_query || '%'
       order by ps.weight desc limit 1) as matched_skill
  from profiles p
  where p.id <> auth.uid()
    and p.onboarded
    and length(coalesce(p_query, '')) >= 2
    and (
      p.username ilike '%' || p_query || '%'
      or p.display_name ilike '%' || p_query || '%'
      or exists (
        select 1 from profile_skills ps join skills sk on sk.id = ps.skill_id
        where ps.profile_id = p.id and sk.name ilike '%' || p_query || '%'
      )
    )
  order by p.help_karma desc, p.reputation desc
  limit p_limit;
$$;

revoke all on function search_profiles(text, integer) from anon;
grant execute on function search_profiles(text, integer) to authenticated;
