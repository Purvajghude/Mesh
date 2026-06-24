# Mesh — Claude Code Context

Read this file first. It gives you enough context to work without exploring the codebase cold.

## What is Mesh?

Mesh is a skill-matching app for builders — a Tinder-style swipe deck where you match with people whose skills *complement* yours (not copy them). When two builders match, an AI engine generates 3 specific, buildable project pitches for what they could create together.

Built for the RedRob AI HR hackathon. RedRob's value: Mesh generates a behavioral skill-graph data flywheel (swipe patterns, match signals, complementarity data) that trains RedRob's HR intelligence.

## Tech Stack

| Layer | Tech |
|---|---|
| Mobile app | Flutter + Riverpod, targeting Android |
| Backend DB | Supabase (PostgreSQL + pgvector) — project ref `luourzpnaeeckaravaxl` |
| AI backend | Python FastAPI + Groq (`llama-3.3-70b-versatile`) — runs locally on port 8000 |
| Auth | Supabase email OTP (8-digit), 12 demo users seeded |

## Key Files

```
lib/
  app/theme/           # AppColors, AppTypography — B&W editorial design system
  data/
    models/            # DeckProfile, AvatarConfig, Pitch, PitchSet, ChatMatch
    repositories/      # SwipeRepository (SwipeResult with matchId)
    services/          # SupabaseService, PitchService (POST /pitches)
  features/
    swipe/presentation/
      swipe_deck_screen.dart   # Main swipe UI, calls showMatchOverlay with matchId
      match_overlay.dart       # Match celebration + pitch card + re-roll
    chat/              # Chat after match (custom uploaded backgrounds)
    profile/           # Profile view (editorial; skills show-more + compound drill-down)
    bank/              # Credit economy: wallet + help-request board + escrow lifecycle
    feed/              # Community feed (text + image posts)
backend/
  engine.py            # Complement map + Groq call → 3 Pitch objects (POST /pitches)
  ranking.py           # Complementarity scorer (pure Python, no ML dep at serve time)
  deck.py              # Fetch candidates + swipe signals → ranking → ordered deck
  embed_skills.py      # OFFLINE one-time: fastembed → skill+profile vectors in pgvector
  main.py              # FastAPI: GET /deck, POST /pitches, GET /health
  .env                 # SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, GROQ_API_KEY
supabase/migrations/   # Schema only — RPCs (get_deck, record_swipe) live in DB only
```

## The Recommendation Engine (Challenge-1 centerpiece)

Complementarity ranking: optimizes for "can these two build something neither could
alone?" — not similarity. Two stages + flywheel:
- **Retrieval**: candidates (onboarded, not me, not swiped) with skills + profile vectors.
- **Ranking** (`ranking.py`): `0.6*complement_fit + 0.2*reciprocity + 0.2*affinity`,
  then diversity re-rank. complement_fit = gap-fill complementarity gated by shared_ground.
  affinity = cosine to the centroid of who you've right-swiped (learns taste, shifts deck).
- Each card gets an `explanation` ("brings Node.js — fills a gap in your stack").
- Embeddings: all-MiniLM-L6-v2 (384-d) via fastembed, generated offline by embed_skills.py,
  stored on `skills.embedding` + `profiles.skill_embedding`. Serve time reads vectors only.
- Flutter `SwipeRepository.getDeck` calls `/deck`; falls back to `get_deck` RPC if backend down.

## Design System

Monochrome editorial. One exception: the match overlay uses full color (the "gacha" moment).
- Ink: `#15130F`, Paper: `#EDEAE3`, Snow: `#F7F5F0`, Graphite: `#57534A`
- Fonts: Archivo (display), Inter (body), Space Mono (mono)
- Colors are only used as signal (error, match bloom, pitch pills) — never decoration

## Current Status (2026-06-24)

- 🧭 **Product pivot (session 11): center of gravity = community FEED of helpers**, not the
  swipe deck. See PLANNING.md session 11 for the full thesis + 6-phase build plan. Matching is
  the hook; help-asks + community + reputation are the retention engine; verified competence is
  the moat; credits deferred (liquidity-first).
- ✅ Phase 1 (migration 0023): typed feed posts (`kind` ask/show/offer/buildlog, `skill_tags`,
  ask `status`); `get_feed` returns them. Composer = kind picker + tags + image. Feed = kind
  filter + per-kind cards + author→profile. **Nav reframed: Feed=home, swipe→Discover, Crew, You;
  Bank removed from nav** (credits deferred, code kept).
- ✅ Phase 0 slice: public profile screen (reused by chat/feed/search), chat name→profile (#7),
  edit display name (#6), custom chat-bg fix (#4). Deferred (need accounts): deploy backend (#8),
  FCM push.
- ✅ Credit economy (migrations 0018–0021) — conserved `credit_ledger` + `help_requests` +
  escrow lifecycle RPCs; **Bank tab** (wallet + help board + post/accept/confirm). See
  CREDITS_DESIGN.md; later phases (demurrage, auto-release, ratings) deferred.
- ✅ Multi-skill crafting (2+ ingredients) + compound drill-down (`skill_components`,
  `skill_recipes_multi`, `GET /skills/{id}/components`) — migration 0019
- ✅ Feed image posts + custom chat backgrounds (migration 0020); skills show-more fold;
  profile redesign (editorial masthead, stat strip, pull-quote vibe)
- ✅ Security hardening complete (migrations 0012–0017); advisor 0 ERRORs
- ✅ Monochrome redesign (PR #1, merged to main)
- ✅ Swipe deck, match overlay, chat, profile — all working
- ✅ POST /pitches — Groq engine live, tested; chat icebreaker auto-seeds top pitch
- ✅ GET /deck — complementarity ranking engine, validated (illustrator → coders ranked top)
- ✅ EXP system (migrations 0006/0007) — earned skill levels; skill_events ledger;
  award_skill_xp; log_collab awards XP per tagged skill; swipe cards show level pips
- ✅ Embeddings populated (45+ skills + 13 profiles, fastembed/all-MiniLM-L6-v2)
- ✅ Infinite skills (POST /profile/skills, embed-on-add) + crafting (POST /craft,
  Groq-named compound skills, recipe cache) — migration 0008; profile UI shows level
  pips + add/craft actions
- ✅ Verified in native Windows app (flutter run -d windows) — deck + WHY chips render
- 🔲 GitHub→XP wiring, streaks (secondary XP sources)
- 🔲 Pitch deck / submission

## DO NOT explore these paths — they're generated, not source

- `build/`, `.dart_tool/`, `.gradle/`, `android/`, `ios/`
- `supabase/.branches/`, `supabase/functions/`

## Running the app

Backend: `cd backend && python -m uvicorn main:app --reload --port 8000`
Flutter: `flutter run` (Android emulator or device, port 8000 proxied via 10.0.2.2)

## Planning log

See [PLANNING.md](PLANNING.md) for all session plans, decisions, and next steps.
