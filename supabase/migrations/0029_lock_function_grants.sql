-- Lock the SECURITY DEFINER functions added across Phases 2–6 to authenticated
-- only. They were revoked `from anon` but not `from public`, so the PUBLIC
-- default EXECUTE still let the anon role call them. Revoking `from public`
-- (then re-granting authenticated) matches the session-8 posture used by the
-- rest of the codebase. rl_check is trigger-only and needs no direct callers.

revoke all on function get_feed(text, integer)            from public;
revoke all on function get_asks_for_me(integer)           from public;
revoke all on function get_post_comments(uuid)            from public;
revoke all on function search_profiles(text, integer)     from public;
revoke all on function get_help_profile(uuid)             from public;
revoke all on function get_top_helpers(text, integer)     from public;
revoke all on function add_comment(uuid, text)            from public;
revoke all on function mark_ask_solved(uuid, uuid)        from public;
revoke all on function report_content(text, uuid, text)   from public;
revoke all on function block_user(uuid)                   from public;
revoke all on function unblock_user(uuid)                 from public;
revoke all on function is_blocked(uuid)                   from public;
-- rl_check is trigger-only: revoke from everyone (Supabase grants anon/auth by
-- default; it errors if called directly, but lock it anyway).
revoke all on function rl_check() from public, anon, authenticated;

grant execute on function get_feed(text, integer)          to authenticated;
grant execute on function get_asks_for_me(integer)         to authenticated;
grant execute on function get_post_comments(uuid)          to authenticated;
grant execute on function search_profiles(text, integer)   to authenticated;
grant execute on function get_help_profile(uuid)           to authenticated;
grant execute on function get_top_helpers(text, integer)   to authenticated;
grant execute on function add_comment(uuid, text)          to authenticated;
grant execute on function mark_ask_solved(uuid, uuid)      to authenticated;
grant execute on function report_content(text, uuid, text) to authenticated;
grant execute on function block_user(uuid)                 to authenticated;
grant execute on function unblock_user(uuid)               to authenticated;
grant execute on function is_blocked(uuid)                 to authenticated;
-- rl_check: no grant — it runs as the definer owner from the insert triggers.
