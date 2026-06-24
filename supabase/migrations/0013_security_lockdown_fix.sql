-- Phase 1 fix: Supabase grants function EXECUTE to anon/authenticated DIRECTLY
-- (not only via PUBLIC), so 0012's "revoke from public" didn't actually remove
-- their access. Revoke from the specific roles.

-- award_skill_xp: backend (service_role) only — strip anon AND authenticated.
revoke execute on function public.award_skill_xp(uuid, uuid, text, numeric, text)
  from anon, authenticated;

-- User-facing RPCs: remove anon (logged-out); authenticated keeps access (0012).
revoke execute on function public.record_swipe(uuid, public.swipe_direction, integer) from anon;
revoke execute on function public.get_deck(integer) from anon;
revoke execute on function public.get_matches() from anon;
revoke execute on function public.get_feed(text, integer) from anon;
revoke execute on function public.log_collab(uuid, text, text) from anon;
revoke execute on function public.log_collab(uuid, text, text, uuid[]) from anon;
revoke execute on function public.collab_skill_options(uuid) from anon;
revoke execute on function public.toggle_reaction(uuid, text) from anon;
revoke execute on function public.toggle_upvote(uuid) from anon;

-- Signup trigger fn: not for API callers (fires as a trigger regardless).
revoke execute on function public.handle_new_user() from anon, authenticated;
