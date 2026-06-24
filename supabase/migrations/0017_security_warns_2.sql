-- Phase 1 follow-up: clear two more advisor WARNs safely.

-- is_match_participant is still anon-reachable via the blanket PUBLIC grant
-- (0014 only revoked the direct anon grant). Remove PUBLIC, but keep it for
-- authenticated — RLS policies on messages/collabs call it, so authenticated
-- MUST retain EXECUTE or chat/collab reads break.
revoke execute on function public.is_match_participant(uuid) from public;
grant  execute on function public.is_match_participant(uuid) to authenticated;

-- chat-media is a public bucket; the broad SELECT policy lets clients LIST every
-- file. Public object URLs (getPublicUrl) don't need it, so drop it to stop
-- listing while image display keeps working.
drop policy if exists "chat media public read" on storage.objects;
