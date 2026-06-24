-- Phase 1 security lockdown (from SECURITY_PLAN.md).
--
-- Closes the "use the public anon key directly" exploits:
--   1. RLS was OFF on 6 tables → anyone with the anon key could read/write them.
--   2. award_skill_xp was anon-EXECUTE-able → anyone could grant unlimited XP to
--      any profile (it takes p_profile as a parameter, not auth.uid()).
-- The Flutter client reaches these tables only via the backend (service-role,
-- which bypasses RLS) or via SECURITY DEFINER RPCs (run as owner), so enabling
-- RLS with no client-write policies does not break the app.

-- ── 1. Enable RLS + read policies on the exposed tables ─────────────────────
-- Owner-scoped reads where there's an owner; internal cache/link tables get RLS
-- with no client policy (backend/definer only). No client INSERT/UPDATE/DELETE
-- anywhere — all writes go through the backend or SECURITY DEFINER functions.

alter table skill_events enable row level security;
create policy "own skill_events" on skill_events
  for select to authenticated using (profile_id = auth.uid());

alter table connected_accounts enable row level security;
create policy "own connected_accounts" on connected_accounts
  for select to authenticated using (profile_id = auth.uid());

alter table portfolio_evidence enable row level security;
create policy "own portfolio_evidence" on portfolio_evidence
  for select to authenticated using (profile_id = auth.uid());

alter table collab_pitches enable row level security;
create policy "participant collab_pitches" on collab_pitches
  for select to authenticated using (auth.uid() in (user_a_id, user_b_id));

-- Global skill-combo cache + collab↔skill link: backend/definer only, no client policy.
alter table skill_recipes enable row level security;
alter table collab_skills enable row level security;

-- ── 2. Lock down RPC execution ──────────────────────────────────────────────
-- award_skill_xp must be BACKEND-ONLY (XP is server-authoritative). Revoke the
-- default PUBLIC grant and hand it only to service_role (the backend). log_collab
-- still calls it fine because log_collab is SECURITY DEFINER (runs as owner).
revoke execute on function public.award_skill_xp(uuid, uuid, text, numeric, text) from public;
grant execute on function public.award_skill_xp(uuid, uuid, text, numeric, text) to service_role;

-- User-facing RPCs: drop anon (logged-out) access, keep authenticated (the app).
revoke execute on function public.record_swipe(uuid, public.swipe_direction, integer) from public;
grant  execute on function public.record_swipe(uuid, public.swipe_direction, integer) to authenticated;

revoke execute on function public.get_deck(integer) from public;
grant  execute on function public.get_deck(integer) to authenticated;

revoke execute on function public.get_matches() from public;
grant  execute on function public.get_matches() to authenticated;

revoke execute on function public.get_feed(text, integer) from public;
grant  execute on function public.get_feed(text, integer) to authenticated;

revoke execute on function public.log_collab(uuid, text, text) from public;
grant  execute on function public.log_collab(uuid, text, text) to authenticated;

revoke execute on function public.log_collab(uuid, text, text, uuid[]) from public;
grant  execute on function public.log_collab(uuid, text, text, uuid[]) to authenticated;

revoke execute on function public.collab_skill_options(uuid) from public;
grant  execute on function public.collab_skill_options(uuid) to authenticated;

revoke execute on function public.toggle_reaction(uuid, text) from public;
grant  execute on function public.toggle_reaction(uuid, text) to authenticated;

revoke execute on function public.toggle_upvote(uuid) from public;
grant  execute on function public.toggle_upvote(uuid) to authenticated;

-- Signup trigger function: never meant to be called via the API. Triggers fire
-- regardless of EXECUTE grants, so revoking client access is safe.
revoke execute on function public.handle_new_user() from public;

-- ── 3. Pin search_path on the flagged functions (advisor WARN) ──────────────
alter function public.xp_to_weight(numeric) set search_path = public, pg_temp;
alter function public.touch_updated_at() set search_path = public, pg_temp;
