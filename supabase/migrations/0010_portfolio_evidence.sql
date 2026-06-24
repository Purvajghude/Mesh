-- Portfolio evidence → AI-judged proof-of-skill XP.
--
-- For skills with no platform to import from (electronics, design, cooking,
-- photography, construction, cinematography...), a builder submits artifacts —
-- photos + a description + links. A multimodal AI (Llama 4 Scout) examines the
-- evidence and awards XP to the demonstrated skills, with a written rationale.
-- Same skill_events ledger → same levels → same recsys. Nothing self-declared.

create table if not exists portfolio_evidence (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references profiles(id) on delete cascade,
  title       text not null,
  description text,
  image_urls  jsonb not null default '[]'::jsonb,
  links       jsonb not null default '[]'::jsonb,
  ai_verdict  jsonb,                       -- {skills:[{name,level,xp,reasoning}], summary}
  created_at  timestamptz not null default now()
);
create index if not exists portfolio_evidence_profile_idx
  on portfolio_evidence (profile_id, created_at desc);

-- Public bucket for portfolio images (so the vision model can fetch them by URL).
insert into storage.buckets (id, name, public)
values ('portfolio', 'portfolio', true)
on conflict (id) do nothing;

drop policy if exists "portfolio public read" on storage.objects;
create policy "portfolio public read" on storage.objects
  for select using (bucket_id = 'portfolio');

drop policy if exists "portfolio auth upload" on storage.objects;
create policy "portfolio auth upload" on storage.objects
  for insert to authenticated with check (bucket_id = 'portfolio');
