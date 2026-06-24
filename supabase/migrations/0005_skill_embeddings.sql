-- Per-skill embedding vectors, used by the complementarity engine (ranking.py)
-- to score how semantically novel one builder's skills are relative to another's.
-- Populated offline by backend/embed_skills.py (all-MiniLM-L6-v2, 384-d).
alter table skills add column if not exists embedding vector(384);
