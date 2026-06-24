-- Mesh credit / time-bank economy — Phase 1 (foundations) + interactive lifecycle.
--
-- Principles (see CREDITS_DESIGN.md):
--   • Conserved, not minted. Helping never prints money. The only faucet is a
--     one-time, identity-gated onboarding grant; the only sink is demurrage.
--   • XP = stock (earned competence, never transferable). Credits = flow.
--   • Price per request, settled by escrow (accept→hold→confirm→release).
--
-- Balance is derived from the append-only ledger (source of truth); profiles.credits
-- is a denormalized cache kept in step by the SECURITY DEFINER functions below.

-- ── Balance cache ────────────────────────────────────────────────────────────
alter table profiles add column if not exists credits numeric not null default 0;

-- ── Append-only double-entry ledger ──────────────────────────────────────────
create table if not exists credit_ledger (
  id           uuid primary key default gen_random_uuid(),
  from_profile uuid references profiles(id) on delete set null,  -- null = faucet
  to_profile   uuid references profiles(id) on delete set null,  -- null = sink
  amount       numeric not null check (amount > 0),
  type         text not null check (type in
                 ('grant','escrow_hold','escrow_release','refund','demurrage')),
  request_id   uuid,
  created_at   timestamptz not null default now()
);
create index if not exists idx_ledger_to   on credit_ledger(to_profile, created_at desc);
create index if not exists idx_ledger_from on credit_ledger(from_profile, created_at desc);

-- ── Help requests — the open-bounty board that makes credits flow ─────────────
create table if not exists help_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  helper_id    uuid references profiles(id) on delete set null,
  skill_id     uuid references skills(id) on delete set null,
  title        text not null,
  description  text,
  size         text not null default 'standard' check (size in ('quick','standard','deep')),
  urgency      text not null default 'normal'   check (urgency in ('normal','urgent')),
  credits      int  not null check (credits between 1 and 12),
  status       text not null default 'open' check (status in
                 ('open','accepted','confirmed','cancelled')),
  created_at   timestamptz not null default now(),
  accepted_at  timestamptz,
  deadline     timestamptz
);
create index if not exists idx_help_status    on help_requests(status, created_at desc);
create index if not exists idx_help_requester on help_requests(requester_id, created_at desc);
create index if not exists idx_help_helper    on help_requests(helper_id, created_at desc);

-- ── RLS — reads scoped; ALL writes go through the functions below ─────────────
alter table credit_ledger enable row level security;
alter table help_requests enable row level security;

drop policy if exists "ledger owner read" on credit_ledger;
create policy "ledger owner read" on credit_ledger for select to authenticated
  using (from_profile = auth.uid() or to_profile = auth.uid());

drop policy if exists "help read" on help_requests;
create policy "help read" on help_requests for select to authenticated using (true);

-- ── Internal helper: authoritative balance from the ledger ───────────────────
create or replace function credit_balance(p_profile uuid)
returns numeric language sql stable security definer set search_path to 'public' as $$
  select coalesce(sum(case when to_profile   = p_profile then amount else 0 end), 0)
       - coalesce(sum(case when from_profile = p_profile then amount else 0 end), 0)
  from credit_ledger;
$$;
revoke all on function credit_balance(uuid) from public;  -- backend-internal only

-- ── Pricing: size base × urgency premium, capped at 12 (no whales) ───────────
create or replace function help_request_price(p_size text, p_urgency text)
returns int language sql immutable as $$
  select least(12, greatest(1, round(
    (case p_size when 'quick' then 1 when 'deep' then 6 else 3 end)
    * (case when p_urgency = 'urgent' then 1.5 else 1.0 end)
  )::numeric))::int;
$$;

-- ── Wallet snapshot for the UI ───────────────────────────────────────────────
create or replace function get_wallet()
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select jsonb_build_object(
    'balance',  credit_balance(auth.uid()),
    'escrowed', coalesce((select sum(credits) from help_requests
                            where requester_id = auth.uid() and status = 'accepted'), 0),
    'claimed',  exists(select 1 from credit_ledger
                         where to_profile = auth.uid() and type = 'grant')
  );
$$;

-- ── Onboarding grant — the sole faucet, one-time, identity-gated ─────────────
create or replace function claim_onboarding_grant()
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); v_bal numeric;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from profiles where id = me and onboarded) then
    raise exception 'finish onboarding to unlock your starter credits';
  end if;
  if exists (select 1 from credit_ledger where to_profile = me and type = 'grant') then
    raise exception 'you have already claimed your starter credits';
  end if;
  insert into credit_ledger (from_profile, to_profile, amount, type)
  values (null, me, 5, 'grant');
  update profiles set credits = credit_balance(me) where id = me returning credits into v_bal;
  return jsonb_build_object('credits', v_bal, 'granted', 5);
end;
$$;

-- ── Post a request (price computed server-side; must be affordable) ──────────
create or replace function post_help_request(
  p_title text, p_description text, p_skill_id uuid, p_size text, p_urgency text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); v_price int; v_id uuid; v_open int;
begin
  if me is null then raise exception 'not authenticated'; end if;
  if coalesce(btrim(p_title), '') = '' then raise exception 'a title is required'; end if;
  v_price := help_request_price(coalesce(p_size, 'standard'), coalesce(p_urgency, 'normal'));
  if credit_balance(me) < v_price then
    raise exception 'not enough credits — this request costs %', v_price;
  end if;
  select count(*) into v_open from help_requests
    where requester_id = me and status in ('open', 'accepted');
  if v_open >= 3 then raise exception 'you already have 3 active requests'; end if;
  insert into help_requests (requester_id, skill_id, title, description, size, urgency, credits)
  values (me, p_skill_id, btrim(p_title),
          nullif(btrim(coalesce(p_description, '')), ''),
          coalesce(p_size, 'standard'), coalesce(p_urgency, 'normal'), v_price)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'credits', v_price);
end;
$$;

-- ── Accept a request → hold the requester's credits in escrow ────────────────
create or replace function accept_help_request(p_request uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); r help_requests%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;
  select * into r from help_requests where id = p_request for update;
  if not found then raise exception 'request not found'; end if;
  if r.status <> 'open' then raise exception 'this request is no longer open'; end if;
  if r.requester_id = me then raise exception 'you cannot accept your own request'; end if;
  if credit_balance(r.requester_id) < r.credits then
    raise exception 'the requester no longer has enough credits';
  end if;
  insert into credit_ledger (from_profile, to_profile, amount, type, request_id)
  values (r.requester_id, null, r.credits, 'escrow_hold', r.id);
  update help_requests
     set status = 'accepted', helper_id = me, accepted_at = now(),
         deadline = now() + interval '72 hours'
   where id = r.id;
  update profiles set credits = credit_balance(r.requester_id) where id = r.requester_id;
  return jsonb_build_object('status', 'accepted');
end;
$$;

-- ── Confirm delivery → release escrow to the helper (+ log XP in the skill) ──
create or replace function confirm_help_request(p_request uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); r help_requests%rowtype;
begin
  if me is null then raise exception 'not authenticated'; end if;
  select * into r from help_requests where id = p_request for update;
  if not found then raise exception 'request not found'; end if;
  if r.requester_id <> me then raise exception 'only the requester can confirm'; end if;
  if r.status <> 'accepted' then raise exception 'nothing to confirm'; end if;
  insert into credit_ledger (from_profile, to_profile, amount, type, request_id)
  values (null, r.helper_id, r.credits, 'escrow_release', r.id);
  update help_requests set status = 'confirmed' where id = r.id;
  -- a completed paid session is also revealed competence → log XP for the helper
  if r.skill_id is not null then
    perform award_skill_xp(r.helper_id, r.skill_id, 'collab', 12, 'help:' || r.id::text);
  end if;
  update profiles set credits = credit_balance(r.helper_id) where id = r.helper_id;
  return jsonb_build_object('status', 'confirmed');
end;
$$;

-- ── Cancel an OPEN request (no unilateral cancel once escrow is held) ─────────
create or replace function cancel_help_request(p_request uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid(); r help_requests%rowtype;
begin
  select * into r from help_requests where id = p_request for update;
  if not found then raise exception 'request not found'; end if;
  if r.requester_id <> me then raise exception 'not your request'; end if;
  if r.status <> 'open' then raise exception 'you can only cancel an open request'; end if;
  update help_requests set status = 'cancelled' where id = r.id;
  return jsonb_build_object('status', 'cancelled');
end;
$$;

-- ── Readers (SECURITY DEFINER so they can join others' public profile cards) ─
create or replace function get_help_board()
returns table(
  id uuid, title text, description text, size text, urgency text, credits int,
  status text, created_at timestamptz, skill_name text,
  requester_id uuid, username text, display_name text, avatar_config jsonb
) language sql stable security definer set search_path to 'public' as $$
  select h.id, h.title, h.description, h.size, h.urgency, h.credits, h.status, h.created_at,
         s.name, h.requester_id, p.username, p.display_name, p.avatar_config
  from help_requests h
  join profiles p on p.id = h.requester_id
  left join skills s on s.id = h.skill_id
  where h.status = 'open' and h.requester_id <> auth.uid()
  order by (h.urgency = 'urgent') desc, h.created_at desc
  limit 100;
$$;

create or replace function get_my_requests()
returns table(
  id uuid, title text, description text, size text, urgency text, credits int,
  status text, created_at timestamptz, deadline timestamptz, skill_name text,
  role text, requester_id uuid, helper_id uuid,
  other_username text, other_display_name text, other_avatar jsonb
) language sql stable security definer set search_path to 'public' as $$
  select h.id, h.title, h.description, h.size, h.urgency, h.credits, h.status,
         h.created_at, h.deadline, s.name,
         case when h.requester_id = auth.uid() then 'requester' else 'helper' end,
         h.requester_id, h.helper_id,
         other.username, other.display_name, other.avatar_config
  from help_requests h
  left join skills s on s.id = h.skill_id
  left join profiles other on other.id =
    (case when h.requester_id = auth.uid() then h.helper_id else h.requester_id end)
  where h.requester_id = auth.uid() or h.helper_id = auth.uid()
  order by h.created_at desc
  limit 100;
$$;

-- ── Grants: user-facing funcs to authenticated only; never anon ──────────────
revoke all on function claim_onboarding_grant()                from public, anon;
revoke all on function post_help_request(text,text,uuid,text,text) from public, anon;
revoke all on function accept_help_request(uuid)               from public, anon;
revoke all on function confirm_help_request(uuid)              from public, anon;
revoke all on function cancel_help_request(uuid)               from public, anon;
revoke all on function get_wallet()                            from public, anon;
revoke all on function get_help_board()                        from public, anon;
revoke all on function get_my_requests()                       from public, anon;

grant execute on function claim_onboarding_grant()                to authenticated;
grant execute on function post_help_request(text,text,uuid,text,text) to authenticated;
grant execute on function accept_help_request(uuid)               to authenticated;
grant execute on function confirm_help_request(uuid)              to authenticated;
grant execute on function cancel_help_request(uuid)               to authenticated;
grant execute on function get_wallet()                            to authenticated;
grant execute on function get_help_board()                        to authenticated;
grant execute on function get_my_requests()                       to authenticated;
