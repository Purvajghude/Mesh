-- Live-capture vs upload, and going ephemeral.
--
-- Evidence is now sent to the AI as base64 and never stored — we keep only the
-- verdict + how it was captured. Live in-app camera capture ('camera') is much
-- harder to fake than a gallery upload, so it earns full XP; uploads earn a
-- reduced share. image_urls stays for back-compat but is empty for ephemeral.

alter table portfolio_evidence
  add column if not exists capture_mode text not null default 'upload'
  check (capture_mode in ('camera', 'upload'));
