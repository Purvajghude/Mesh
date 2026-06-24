-- Phase 3: prove you own a platform handle before its stats become your XP.
-- Flow: request a one-time code → put it in your platform bio/profile → connect
-- re-reads that public field and only grants XP if the code is present. Stops
-- "connect torvalds' GitHub and inherit his stats."

alter table connected_accounts
  add column if not exists verify_nonce text,
  add column if not exists verified boolean not null default false;
