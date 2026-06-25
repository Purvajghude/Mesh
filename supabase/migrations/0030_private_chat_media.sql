-- Phase 6 (follow-up): private chat-attachment images + storage path scoping.
--
-- DM photos/files were world-readable public URLs. New chat attachments go to a
-- PRIVATE bucket, readable only by the two match participants via short-lived
-- signed URLs. Existing (public) attachments keep working unchanged. Uploads to
-- the public buckets are scoped to the uploader's own folder (no writing into
-- someone else's path).

insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;

-- Private chat attachments: path is {matchId}/{uid}/{file}; only match
-- participants may read or write. is_match_participant() checks auth.uid().
drop policy if exists "chat-attachments participant read" on storage.objects;
create policy "chat-attachments participant read" on storage.objects
  for select to authenticated using (
    bucket_id = 'chat-attachments'
    and is_match_participant(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "chat-attachments participant insert" on storage.objects;
create policy "chat-attachments participant insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'chat-attachments'
    and is_match_participant(((storage.foldername(name))[1])::uuid)
  );

-- Tighten the public buckets: you may only upload into your own uid folder
-- (path is now {uid}/...). Replaces the old "any authenticated, any path" rules.
drop policy if exists "chat media authenticated upload" on storage.objects;
create policy "chat-media own-folder insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'chat-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "portfolio auth upload" on storage.objects;
create policy "portfolio own-folder insert" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'portfolio'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
