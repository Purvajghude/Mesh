-- Phase 1 cleanup: address the meaningful advisor WARNs.
-- Intentionally left as-is (documented): `skills` INSERT-true policy (open skill
-- vocabulary + client GitHub import rely on it), `vector` extension in public
-- (moving it is invasive and risks the embedding columns), the "authenticated can
-- execute" RPC warnings (the app legitimately calls those as a signed-in user),
-- and leaked-password protection (a dashboard toggle; auth is OTP, not passwords).

-- is_match_participant: no reason for logged-out callers to reach it.
revoke execute on function public.is_match_participant(uuid) from anon;

-- collabs: the "members manage collabs" policy had WITH CHECK (true), letting a
-- member write arbitrary collab rows. Scope the write check to membership too.
drop policy if exists "members manage collabs" on collabs;
create policy "members manage collabs" on collabs
  for all to authenticated
  using (
    exists (select 1 from collab_members cm
            where cm.collab_id = collabs.id and cm.profile_id = auth.uid())
  )
  with check (
    exists (select 1 from collab_members cm
            where cm.collab_id = collabs.id and cm.profile_id = auth.uid())
  );

-- Drop the broad SELECT policy on the (now unused, ephemeral) portfolio bucket so
-- it can't be listed. Public object-URL access doesn't need this policy.
drop policy if exists "portfolio public read" on storage.objects;
