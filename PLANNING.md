# Mesh — Planning Log

Running log of what we're building, when, and why. Newest entries at the top.

---

## 2026-06-23 (session 10) — Economy BUILT + skills/feed/chat features + profile redesign

Built the credit economy (from session-9 design) and a batch of UX upgrades. Migrations
0018–0021 applied via MCP; advisor = 0 ERRORs (only the project's existing SECURITY-DEFINER
WARN pattern + pre-existing INFOs). Flutter analyze clean; backend imports clean; new
endpoints 401 without a token.

- **Credit economy (migration 0018)** — conserved double-entry `credit_ledger` +
  `help_requests` + `profiles.credits` cache. RPCs (SECURITY DEFINER, authenticated-only):
  `get_wallet`, `claim_onboarding_grant` (one-time, gated on onboarded), `post_help_request`
  (price = size base × urgency, cap 12, ≤3 active), `accept_help_request` (escrow hold),
  `confirm_help_request` (release + logs helper XP), `cancel_help_request`, `get_help_board`,
  `get_my_requests`. **Verified the full escrow lifecycle in a rolled-back txn:** grant 5 →
  post 3 (req 5→2, held) → confirm (helper 0→3); conservation holds (2+3=5).
  - New **Bank tab** (5th nav slot): ink balance card + claim CTA, open-request board with
    "I'll help", your-requests with confirm/cancel, post sheet (size picker + urgent +50% +
    optional skill tag, live price). `EconomyRepository`, `Wallet/BoardRequest/MyRequest`
    models, `walletProvider`/`helpBoardProvider`/`myRequestsProvider`.
- **0021** — lint tightening: `credit_balance` revoked from anon/authenticated
  (backend-internal), `help_request_price` search_path pinned, `get_feed` anon-revoked.
- **Skill components + multi-craft (migration 0019)** — `skill_components` (drill-down) +
  `skill_recipes_multi` (signature cache), backfilled from old pairwise recipes. Backend
  `craft_skill(list)` now fuses **2+** skills; new `GET /skills/{id}/components`.
  Profile: tap a compound chip → sheet showing its component skills + your level in each.
- **Feed images (migration 0020)** — `feed_posts.image_url`; `get_feed` returns it
  (drop+recreate). Compose sheet has add-photo (→ public `portfolio` bucket); post cards
  render the image; posts can be image-only.
- **Custom chat backgrounds (0020)** — `profiles.chat_bg_url`; "Upload your own" in the bg
  picker (→ public `chat-media` bucket, washed toward paper for legibility); chat renders the
  custom image when `chat_bg='custom'`.
- **Skills overcrowding** — show first 6 atomic skills + "show N more"; crafted compounds
  pulled into their own "CRAFTED" row.
- **Profile redesign (/impeccable rules applied directly — skipped the PRODUCT.md/DESIGN.md
  init scaffold; the monochrome system is already committed/documented)** — editorial
  masthead (left-aligned, big Archivo name), the two identical stat cards replaced by one
  divided stat strip (now incl. credits), vibe as a pull-quote, section heads with rules.
- Demo note: tested economy on aanya/ananya via rolled-back txn → no demo-data pollution.
- Not built (deferred): demurrage decay, 72h auto-release job, ratings/reputation, velocity
  graph cycle-detection (all in CREDITS_DESIGN.md §11 later phases).

---

## 2026-06-23 (session 9) — Credit/time-bank economy (DESIGN, not built)

- Brainstorm via 3-lens council (mechanism design + growth + trust&safety). Full design in
  **`CREDITS_DESIGN.md`**. No code.
- Key decisions: credits are a **conserved transfer ledger** (NOT minted on help — free help
  earns XP/karma only); **XP prices credits** (level → rate band), credits never buy XP;
  **price per request via escrow** (accept→hold→confirm/auto-release-72h), no time metering;
  urgency = paid +50% premium; gated 5-credit onboarding grant + gentle demurrage; velocity
  caps + new-pair friction + (later) graph cycle-detection.
- **Sequencing rule:** liquidity before economy — credits dormant until a campus is match-
  liquid. GTM wedge = be the team-formation tool for ONE hackathon on a contact's campus;
  urgent-request feed = the retention engine; ghost-profile match-pull invites = virality.
- RedRob angle upgraded: revealed outcome-labeled collaboration data + per-campus skill-
  liquidity heatmap. Open questions listed in the doc §12.

---

## 2026-06-23 (session 8) — Security hardening (Phases 1 & 2 done)

- Council (3 agents) + Supabase advisor → `SECURITY_PLAN.md`. Two front doors found:
  unauthenticated backend (trusts body `user_id` + service-role) AND direct PostgREST
  (6 tables RLS-off + `award_skill_xp` anon-callable).
- **Phase 1 (migrations 0012–0014):** RLS on the 6 tables (advisor 6 ERRORs→0);
  `award_skill_xp` revoked from anon/authenticated (backend-only); user-facing RPCs →
  authenticated only; search_path pinned; collabs write policy scoped; portfolio bucket
  read-policy dropped. Verified privileges via `has_function_privilege`.
- **Phase 2:** FastAPI `current_user` JWT dependency (verifies via `/auth/v1/user`),
  `user_id` removed from all request models, `/pitches` participant check, CORS noted.
  Flutter: `SupabaseService.accessToken` + `ApiConfig.headers()`; all 5 services/repos send
  `Bearer` token, no more `user_id`. Verified: no-token/garbage-token → 401; analyze clean.
- Key rotation (Phase 0) skipped per Purvaj (keys backend-only; frontend has only anon key).
- **Caveat:** phone app must be rebuilt (old build → 401 against the now-auth backend).
- **Phase 3 (migrations 0015/0016):** collab XP deduped per (member,skill,match); manual
  skill add = first-time XP only; portfolio per-skill lifetime cap (120) + ≤4 skills/submit +
  server-derived credible. Handle-ownership proof: `/integrations/challenge` → one-time code
  in platform bio (GitHub bio / CF name / LeetCode About / Chess.com name) → connect verifies
  before granting. 2-step connect UX added to profile.
- **Phase 4:** untrusted-data delimiters + anti-injection in portfolio judge, pitch engine,
  compound-namer; skill-name validation + embedding fuzzy-dedup (≥0.93).
- **Phase 5:** slowapi rate limits on AI endpoints (added `slowapi`; lock = 75 pkgs).
- **Migrations 0017:** is_match_participant locked to authenticated; chat-media listing dropped.
- Advisor: 0 ERRORs. Backend imports clean; full Flutter analyze clean. Verified 401s + grants.
- Dashboard-only left: OTP send-rate, leaked-password toggle. ALL security phases done.

---

## 2026-06-22 (session 7) — Live capture (Snapchat-style) + ephemeral proof

### Decision (Purvaj)
- Anti-fraud: in-app **live camera** capture beats uploads (can't grab internet pics).
- **Ephemeral**: capture → verify → log → discard. No image stored anywhere.
- **XP differential**: camera = full XP; upload = reduced (gallery could be anything).
- Demo target = real **Android phone** (live camera works there; not on Windows desktop).
- Honest caveat noted to Purvaj: camera-capture is strong friction, not unspoofable
  (could film a screen); we stamp "verified live · timestamp" as the honest claim.

### Shipped (migration 0011)
- Confirmed Groq Llama 4 Scout accepts **base64** images → fully ephemeral (no storage).
- `portfolio.py`: `_judge` takes base64; `submit_evidence(... capture_mode)` applies
  `_CAPTURE_MULT = {camera:1.0, upload:0.3}`; stores ONLY verdict + capture_mode (image_urls=[]).
  `portfolio_evidence.capture_mode` column added.
- `POST /portfolio/submit` now takes `images_b64` + `capture_mode`. Verified end-to-end:
  upload mode → XP ×0.3 (Soldering/PCB Assembly 6xp); camera would be full.
- Flutter: `image_picker` added; profile "add evidence" → chooser (Capture live / Upload),
  camera=pickImage(source.camera), upload=pickMultiImage, base64 (resized 1280/q70, no bucket),
  submit with captureMode. Verdict dialog shows "📸 verified live" vs "uploaded · reduced XP".
  Portfolio cards show skills + live/upload badge (no image — ephemeral).
- Note: image host must allow Groq's fetcher (we send base64 now, so moot for live capture).

### Remaining
- Strava/Spotify OAuth (later). Video evidence (later). Otherwise feature-complete.

---

## 2026-06-22 (session 6) — More platforms + AI-vision portfolio

### Platform integrations (now 4 live)
- Added Codeforces, LeetCode, Chess.com to `integrations.py` REGISTRY (all public APIs,
  one mapper each). Verified in isolation: tourist (CF 4009), votrubac (LC 3822),
  hikaru (chess 3403) → correct skill XP. Flutter tiles flipped to active.
  - CF → Competitive Programming + Problem Solving; LC → Problem Solving + Algorithms;
    Chess.com → Strategy. Strava/Spotify still OAuth-deferred.

### AI-vision portfolio (skills with no platform) — the beautiful idea
- **Concept:** every skill is evidence-backed via two rails — Platform (auto-import) or
  Portfolio (AI-judged). Nothing self-declared. Strongest RedRob/Challenge-1 story.
- Groq free tier HAS a multimodal model: `meta-llama/llama-4-scout-17b-16e-instruct`.
- Migration 0010: `portfolio_evidence` table + public `portfolio` storage bucket + policies.
- `backend/portfolio.py` — `_judge()` sends photos+description to Llama 4 Scout (vision) →
  structured JSON {skills:[{name,level,xp,reasoning}],summary,credible}; awards XP (cap 50/
  skill, source 'project'), stores evidence, recomputes profile vector.
- Endpoints: `POST /portfolio/submit`, `GET /portfolio`.
- **Verified end-to-end:** uploaded a real Arduino photo to the Supabase bucket → Scout
  fetched it → judged Electronics (L3,+35) + Soldering (L3,+35) with specific reasoning.
  (Note: image host must allow Groq's fetcher — Wikimedia 403s; Supabase public bucket works.)
- Flutter: `PortfolioService` (uploadImages→bucket + submit + list), `myPortfolioProvider`,
  profile "portfolio" section — pick photos → title/desc/links sheet → upload → AI verdict
  dialog (earned XP + reasoning); entries render with thumbnail strips.

### Decisions (Purvaj)
- Portfolio = AI judge WITH vision; evidence = photos + links (video later).
- Deck is being handled by teammates — not our scope.

### Remaining
- Strava/Spotify OAuth (later). Video evidence (later). Everything else is built.

---

## 2026-06-22 (session 5) — Connected accounts → proof-of-skill XP

### Decision (Purvaj)
- Build a GENERIC integration framework, **GitHub real now**, others (Codeforces/LeetCode/
  Chess.com public; Strava/Spotify OAuth) framework-ready and added later.
- Strategic frame: Mesh aggregates *verifiable* cross-platform competence → the strongest
  RedRob data-flywheel pitch (no HR tool has evidence-backed, multi-source skill graphs).

### Shipped (migration 0009)
- `connected_accounts` table (provider, handle, stats, granted_xp); 'integration' added to
  skill_events sources.
- `backend/integrations.py` — provider REGISTRY (fetch→stats→skill-XP grants). Adding a
  provider = one entry. **GitHub** implemented: one public API call → languages + stars →
  XP per language (12/repo, cap 60) + "Open Source" from stars.
- `connect_account` awards only the positive DELTA per skill on re-sync (no double-count),
  recomputes profile vector, upserts the account.
- Endpoints: `POST /integrations/connect`, `GET /integrations`, `GET /integrations/providers`.
- **Verified end-to-end:** connected Purvaj's real GitHub (purvajghude, 14 repos) → XP to
  Dart/Python/HTML(+60)/TypeScript/JavaScript; re-sync awarded [] (idempotent).
- Flutter: `IntegrationService` + models, `connectedAccountsProvider`, profile "proof of
  skill" section — GitHub tile connects (handle sheet → result dialog of earned XP);
  Codeforces/LeetCode/Chess.com/Strava shown as "soon" tiles (the vision).

### Next provider adds (trivial via framework, public APIs)
- codeforces: `api/user.info` + `user.status` → Competitive Programming / Algorithms
- leetcode: unofficial GraphQL → Problem Solving + languages
- chesscom: public API → Strategy

### Remaining overall
- Secondary providers above (optional), Strava/Spotify OAuth (later), **pitch deck**.

---

## 2026-06-22 (session 4) — Roadmap: EXP + Infinite Skill Tree

### Decisions (Purvaj)
- **Infinite Craft = the full leveling skill tree** (not just open vocab, not just a combo
  game): atomic skills level via EXP; combining your *leveled* skills crafts higher-order
  compound skills/branches; vocabulary is open + infinite (any skill, auto-embedded).
- **Build order: all of it, one by one** → (1) verify app on emulator, (2) EXP system,
  (3) infinite skills + crafting tree.
- Deps frozen → `backend/requirements.lock` (71 pkgs, known-good on Python 3.14).

### Strategic frame (why this wins RedRob)
Mesh stores **evidence of skills, not self-reported skills.** A skill level is EARNED
(collabs, repos, certs, projects). For an AI HR company that's the whole ballgame — a
graph of *verified, demonstrated competence* no résumé pile has. EXP makes the recsys
rank by real ability (proficiency weight = earned XP) and supercharges the data flywheel.

### Build plan (in order)
1. ⏳ **Verify on emulator** — BLOCKED on Purvaj (auth wall + 10.0.2.2 needs Android target).
   Checklist handed off. Full project compiles clean; engine validated by curl.
2. ✅ **EXP / expertise system — DONE** (migrations 0006 + 0007):
   - `skill_events` ledger (seed|collab|repo|cert|project, points, ref); `profile_skills.xp`
     cache; `xp_to_weight()` curve (ln, ~100xp→1.0); `award_skill_xp()` fn.
   - Back-fill preserved all weights exactly (recsys unaffected) — verified.
   - `log_collab` now takes skill ids → awards both members 18xp per tagged skill they have;
     `collab_skill_options()` powers the picker. Collab dialog has a skill multi-select.
   - `/deck` payload carries per-skill `level` (1–5) + `xp`; swipe card shows level pips.
   - Flutter: `DeckSkill` model, `_SkillTag` + `_LevelPips` widgets.
3. ✅ **Infinite skills + crafting tree — DONE** (migration 0008):
   - Open vocabulary: `POST /profile/skills` find-or-creates any skill + embeds it on the
     fly (lazy fastembed in `embeddings.py`; `/deck` stays read-only/light). Self-added
     skills start at ~L2 (`START_XP_MANUAL=5`) — earned, not claimed.
   - Crafting: `POST /craft` combines two L3+ skills → Groq-named compound skill, embedded,
     cached in `skill_recipes` (deterministic per pair, Infinite-Craft style). Verified:
     HTML+TypeScript → "Web Architecture" (L4); re-craft returns cached (crafted_now=false).
   - `skills.is_compound` + `blurb`; XP sources extended with 'manual','craft'.
   - Profile vector recomputed on every skill change (keeps recsys affinity accurate).
   - Flutter: `SkillService`, `MySkill` model, profile screen shows level pips + "add" +
     "craft" actions; compound skills render inked with a node glyph; craft result dialog.
   - Backend verified via curl; Flutter compiles (analyze pending final full run).

### Demo data note
- Reset Purvaj's swipes (deck now populates). Purvaj gained a crafted "Web Architecture"
  compound + a self-added "Technical Writing" (L2) from testing — both are fine demo artifacts.

### Status of recsys (built last session)
Live + validated. `/deck` ranks by complementarity; WHY chips truthful. See session 3 below.

---

## 2026-06-22 (session 3) — Recommendation Engine BUILT

### Shipped — the complementarity ranking engine is live end-to-end
- `backend/embed_skills.py` — offline script; embeds 45 skills + 13 profiles with
  fastembed (all-MiniLM-L6-v2, local, 384-d) into pgvector. **Ran successfully.**
- `backend/ranking.py` — pure-Python complementarity scorer (no ML dep at serve time):
  complementarity + shared_ground gate + reciprocity + affinity (taste centroid) +
  diversity re-rank. Produces a "why you're seeing this" explanation per candidate.
- `backend/deck.py` — fetches candidates/skills/swipe-signals, calls ranking.
- `backend/main.py` — new `GET /deck?user_id=&limit=` endpoint.
- Migration `skill_embeddings` — added `skills.embedding vector(384)`.
- Flutter: `api_config.dart` (shared base URL), `DeckProfile.explanation`,
  `SwipeRepository.getDeck` calls `/deck` (RPC fallback if backend down),
  `_WhyChip` in swipe_card.dart shows the engine's reasoning.

### Validated (live curl, Sara the illustrator)
- Top of her deck = coders (Dev, Ananya, Rohan) + diverse builders. Fellow designer
  Aanya ranks #9. **Complementarity-over-similarity, demonstrated.**
- Affinity signal works: Sara's one like was a coder → other coders get an affinity bump.
- Explanations truthful: "brings Node.js — fills a gap in your stack" / "brings Figma ·
  you connect through Illustration" (high-overlap case).

### Tech decisions made (as senior dev, per Purvaj's delegation)
- fastembed works on Python 3.14 (onnxruntime 1.27). Embeddings generated offline,
  stored in DB → live endpoint is pure numpy-free Python = bulletproof for demo.
- Ranking weights: complement 0.60, reciprocity 0.20, affinity 0.20 (tunable, explainable).
- SHARED_GROUND_FULL=0.55 gate; DEMO_RECIPROCITY_PRIOR=0.70 (matches record_swipe RPC).

### Still to do
- Run app on emulator, verify the WHY chip renders + deck order looks right (live demo).
- Optional: visible "deck re-ranked after your swipes" moment for the demo.
- Pitch deck slides.

---

## 2026-06-22 (session 2) — Recommendation Engine PRD

### Decisions locked (from brainstorm)
- **Hackathon fit confirmed:** Mesh = Challenge 1 (Build an AI System). Reframed from
  "Tinder for skills" → "complementarity recommendation engine + RedRob data flywheel."
- **Build window:** ~1 week → build the real engine, not a mock.
- **Deliverable:** deck PDF + live app demo → recsys must run end-to-end.
- **AI focus:** the matching/ranking engine is the centerpiece (the "Instagram-level" AI).

### Artifact created
- `PRD.md` — full PRD for the Complementarity Engine (2-stage retrieval+ranking + flywheel).

### Architecture agreed (high level)
- Stage 1: retrieval-by-gap-fill using pgvector skill embeddings (not nearest-neighbor).
- Stage 2: transparent weighted ranking (complementarity + shared_ground + reciprocity +
  affinity + project_potential − diversity). Explainable on purpose (judge-friendly).
- Stage 3: flywheel — every swipe = labeled training row; online affinity/reciprocity
  updates; offline weight retrain. This is the RedRob data product.
- Multi-model coordination: embeddings → ranking → Groq pitches, with pitch confidence
  feeding back into ranking.

### Open decisions (see PRD §6)
- Embeddings vs category-vectors for retrieval
- Ranking in Python backend vs Supabase RPC
- Live online-learning in demo (yes/no)
- "Why you're seeing this" explainability chip (recommend yes)

### Next step
- Resolve the 4 open decisions, then build the `/deck` ranking endpoint + explainability chip.

---

## 2026-06-22 — AI Engine + Hackathon Strategy

### Session summary
Built the entire `/pitches` AI pipeline from scratch:
- `backend/engine.py` — complement map builder + Groq LLM call (structured JSON output)
- `backend/main.py` — FastAPI with POST /pitches (cache → fetch → Claude → INSERT → return)
- `lib/data/models/pitch.dart` + `pitch_service.dart` — Flutter models + HTTP client
- `match_overlay.dart` — added matchId param, async pitch loading, _PitchCard widget, next pitch / ↻ re-roll buttons
- `swipe_deck_screen.dart` — passes result.matchId to showMatchOverlay
- `supabase/migrations/0004_collab_pitches.sql` — collab_pitches table (live in DB)

**Tested end-to-end:** Sara ↔ Purvaj match → 3 pitches returned in ~1s (Groq free tier).

### Stack decisions
- Switched from Anthropic Claude → Groq (`llama-3.3-70b-versatile`) — free tier, no API cost
- Groq JSON mode + Pydantic validation for structured pitch output
- Cache strategy: each re-roll = new INSERT row; SELECT latest by created_at DESC

### Hackathon context
- **Event:** RedRob AI Ideathon
- **Track:** Challenge 1 — Build an AI System (for developers/engineers)
- **Submission:** Pitch deck PDF (mandatory template)
- **Our angle:** Mesh = AI-native skill-complementarity engine + data flywheel for RedRob's HR intelligence

### Pitch frame for judges
> Mesh models builder talent as a weighted skill graph, computes complementarity (who fills whose gaps — not who's similar), generates specific buildable project pitches with an LLM, and feeds behavioral signal (swipe patterns, match data) back into RedRob's HR intelligence. Every swipe is a labeled training example.

### Remaining work
1. **Demo polish** — update Purvaj's vibe_statement to something presentable
2. **Chat icebreaker** — auto-seed top pitch as first chat message when "Say hi" is tapped
3. **Pitch deck** — slides using RedRob's mandatory template
4. **Token optimization** — CLAUDE.md created this session (see below)

### Token optimization strategy (meta)
Problem: new sessions spend 20-30% of tokens re-deriving context by reading the codebase.
Solution implemented: `CLAUDE.md` in project root — Claude reads this first and gets enough
context to work immediately without cold-exploring the repo. Key sections: what it is,
tech stack, key file paths, current status, what NOT to explore.

---

## 2026-06-21 — Monochrome Redesign

- Full B&W editorial redesign (PR #1, merged)
- Design system: ink/paper/snow/graphite tokens
- Match overlay: gacha-style sigil animation, colour bloom as the one exception to monochrome
- 12 demo users seeded with skills, vibes, avatars
- Supabase: get_deck + record_swipe RPCs live (not in migrations)
