# Mesh — Security & Anti-Abuse Plan

**Status:** In progress · 2026-06-23 · derived from a 3-agent red/blue/AI review + Supabase Security Advisor.

## Progress
- ✅ **Phase 1 — Supabase lockdown** (migrations 0012–0014). RLS enabled on all 6 exposed
  tables (advisor: 6 ERRORs → 0); `award_skill_xp` revoked from anon/authenticated (anon can
  no longer mint XP — verified); user-facing RPCs locked to `authenticated`; `search_path`
  pinned; `collabs` write policy scoped to membership; unused `portfolio` bucket read-policy
  dropped. Verified the app's roles still have what they need.
- ✅ **Phase 2 — Backend auth.** FastAPI now verifies the Supabase JWT (`current_user`
  dependency → `/auth/v1/user`), derives the user from the token, and `user_id` is gone from
  every request body. `/pitches` checks match participation. Verified: unauthenticated +
  garbage-token calls → 401; `/health` public. Flutter sends `Authorization: Bearer` on all
  backend calls (`ApiConfig.headers()`); analyzes clean.
- ✅ **Phase 3 — XP integrity** (migrations 0015/0016 + code). Manual skill add grants XP
  only on first add; collab XP deduped per (member, skill, match); portfolio per-skill
  lifetime cap (120) + max 4 skills/submission; server-derived `credible`. **Handle-ownership
  proof**: `/integrations/challenge` issues a one-time code the user puts in their platform
  bio/profile (GitHub bio, CF name, LeetCode About, Chess.com name/location); connect re-reads
  that field and grants XP only if the code is present + `unique(provider,handle)` intent via
  verified flag. 2-step connect UX in the app.
- ✅ **Phase 4 — AI hardening.** Portfolio judge + pitch engine + compound-namer wrap user
  text in untrusted-data delimiters with anti-injection instructions; skill names validated
  (charset/length) + fuzzy-deduped via embedding cosine (≥0.93) to stop graph pollution.
- ✅ **Phase 5 — rate limiting.** `slowapi` on the AI endpoints (portfolio 5/min, pitches &
  craft & connect 10/min, skills 20/min), keyed by IP.
- ⚠️ **Phase 0 — key rotation:** skipped per Purvaj (keys are backend-only; confirmed not in
  the frontend — Flutter `.env` holds only URL + anon key).
- 🔲 **Dashboard-only (manual, ~2 min each):** lower Supabase Auth OTP send rate; enable
  leaked-password protection. Both are toggles in the Supabase dashboard, not code.
- ✅ Advisor: **0 ERRORs**. Remaining WARNs are accepted-by-design (open-vocab `skills`
  insert; `vector` ext in public; the app's own RPCs callable by signed-in users) or the
  two dashboard toggles above.

> **Action needed:** the phone app must be **rebuilt/hot-restarted** — the old build sends
> `user_id` with no token and will now get 401 from the (auth-required) backend.

## The core problem: two wide-open front doors

Mesh has **two** ways to reach the data, and both currently trust the client:

1. **The FastAPI backend** runs with the **service-role key** (bypasses all RLS), is reachable with `CORS *`, and **takes `user_id` from the request body with no token check**. Anyone who can reach the host can act as any user via `curl`.
2. **Supabase PostgREST directly** — confirmed by the Security Advisor:
   - **6 tables have RLS DISABLED** (ERROR): `skill_events`, `connected_accounts`, `portfolio_evidence`, `collab_pitches`, `skill_recipes`, `collab_skills`. The **public anon key** (shipped in the app) can read/write these directly — no backend needed.
   - **`award_skill_xp` is executable by `anon`** via `/rest/v1/rpc/award_skill_xp`. **Anyone with the public key can grant unlimited XP to anyone**, bypassing every server-side cap.

Everything else (XP fraud, prompt injection, cost abuse) is second-order — but these two doors must be shut first.

---

## Phase 0 — Rotate exposed secrets (now, ~5 min · YOU)
The `GROQ_API_KEY` and Supabase **service-role key** were pasted in chat → treat as compromised.
- Supabase Dashboard → Settings → API → **roll `service_role`**; update `backend/.env`.
- console.groq.com → revoke + reissue the Groq key; update `backend/.env`.
- `.env` is already gitignored & untracked — good; keep it that way.

## Phase 1 — Shut the Supabase direct-access door (high leverage, mostly SQL, ~30 min)
This closes the no-backend-needed exploits and is the fastest big win.
1. **Enable RLS + owner-only policies** on the 6 flagged tables. Reads = `profile_id = auth.uid()` (or participant, for collab tables); **no client writes** (XP/portfolio/pitches are written only by the backend via service-role, which bypasses RLS).
2. **Revoke `EXECUTE` on internal RPCs** from `anon`/`authenticated`: `award_skill_xp` (most critical — must be backend-only), `is_match_participant`, `collab_skill_options`, `handle_new_user`. Keep user-facing RPCs (`record_swipe`, `get_deck`, `get_matches`, `get_feed`, `log_collab`, `toggle_reaction`, `toggle_upvote`) executable by **`authenticated` only** (revoke from `anon`).
3. **Tighten permissive policies** flagged by the advisor: `collabs` "members manage collabs" (`WITH CHECK true`) and `skills` "authenticated can add skills" (`INSERT true`).
4. **Pin `search_path`** on `touch_updated_at` and `xp_to_weight` (advisor WARN).
5. **Storage**: drop the unused public `portfolio` bucket (we went ephemeral); narrow `chat-media` SELECT so it can't be listed.
6. Re-run the advisor → expect 0 ERRORs.
> Safe for the app: the Flutter client reaches these tables only through the backend/RPCs, not direct reads — so enabling RLS won't break it.

## Phase 2 — Authenticate the backend (the keystone, ~1–2 h)
1. **Flutter**: attach the Supabase access token on every backend call — `Authorization: Bearer ${session.accessToken}` (in `pitch_service`, `skill_service`, `integration_service`, `portfolio_service`, `swipe_repository`).
2. **FastAPI**: one dependency that verifies the JWT (`PyJWT`, HS256 with the project JWT secret; later JWKS/ES256) and returns `user_id = payload["sub"]`. **Delete `user_id` from every request model** — derive it from the token only.
3. Add a **participant check** on `/pitches` (assert the caller is in the match).
4. **CORS**: set `allow_origins=[]` (native app needs no CORS) or the exact web origin if demoing web.

## Phase 3 — XP integrity / anti-cheat (makes "verified data" honest)
- **`capture_mode` is client-asserted** → today the camera-vs-upload multiplier is cosmetic. Either (a) drop the multiplier and call portfolio XP "AI-assessed, unverified," or (b) make "camera" server-enforceable later (Play Integrity / device attestation). Be honest in the pitch until (b).
- **Handle ownership proof** for integrations: a one-time nonce the user puts in their public bio (GitHub/Codeforces/LeetCode/Chess.com), re-read and matched before granting XP; else store handle, grant 0. Add `unique(provider, handle)` so famous handles can't be farmed.
- **Caps & dedup**: manual skill add grants XP only on *first* add; collab XP once per `(match, skill)`; portfolio per-skill lifetime cap + image perceptual-hash dedup; cap skills-per-submission and total XP/submission.

## Phase 4 — AI hardening (prompt injection)
- Wrap user text (`title`/`description`/`links`, `vibe_statement`, skill names) in explicit **"untrusted data" delimiters**; instruct the model that text trying to dictate scores = gaming → `credible:false`.
- **Score from the image, not the text**; award 0 to skills not visually shown.
- Use Groq **JSON mode + Pydantic validation** (like the pitch engine); **derive `credible` server-side**, never trust the model's boolean.
- **Cap skill count per verdict**; validate skill names (length/charset/profanity); fuzzy-dedupe new skills against existing via embedding cosine before creating (anti graph-pollution). Moderate LLM-named compound skills (they're global).

## Phase 5 — Abuse / cost
- **Rate limit** the Groq endpoints (`slowapi`, keyed by authenticated user): `/portfolio/submit` ~3/min, `/pitches` & `/craft` ~5–10/min, `/profile/skills` ~20/min.
- Lower **Supabase OTP** send rate (Dashboard → Auth → Rate Limits); consider CAPTCHA on sign-in.
- Enforce **image byte/size caps** on portfolio submits (cost/DoS).
- Enable **leaked-password protection** (advisor WARN; minor since auth is OTP).

## Phase 6 — Transport (before any real-world use)
- Backend is plain HTTP on LAN → the JWT crosses WiFi in cleartext. Fine on a trusted demo network; for anything real, terminate **TLS via Cloudflare Tunnel/ngrok** or deploy to Render/Fly/Railway (managed HTTPS) and drop the LAN IP.

---

## Recommended order & hackathon reality
- **Do now:** Phase 0 (rotate) + **Phase 1 (RLS + revoke RPC)** — fast, mostly SQL, and closes the trivially-exploitable "just use the anon key" path. Highest leverage.
- **Do next:** Phase 2 (backend auth) — the proper fix for the service-role bypass.
- **Then:** Phase 3 (so the RedRob "verified data" claim is true), Phase 4–5 (depth), Phase 6 (when leaving the demo network).

**Honest framing for judges:** until Phases 1–3 land, describe XP as "AI-assessed signals," not "cryptographically verified." The architecture *supports* verification (server-authoritative XP, ownership proofs) — that's the credible story; overclaiming is the risk.
