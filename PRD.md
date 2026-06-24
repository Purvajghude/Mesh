# Mesh — Product Requirements Document

**Status:** Draft v0.1 (2026-06-22)
**Hackathon:** RedRob AI Ideathon — Challenge 1 (Build an AI System)
**Deliverable:** Pitch deck PDF + live app demo
**Build window:** ~1 week

---

## 1. One-liner

**Mesh is a complementarity recommendation engine for builders.** Tinder optimizes
for similarity and attraction; Instagram for engagement. Mesh optimizes for a harder,
more valuable signal: *"Can these two people build something neither could alone?"* —
the exact problem enterprise HR can't solve, and the data flywheel RedRob can't buy.

## 2. Why this wins Challenge 1

Challenge 1 wants a *technical AI-native system: intelligent search, multi-model
coordination, AI copilots that change how people work.* Mesh is all four:

| Challenge 1 keyword | Mesh |
|---|---|
| Intelligent search | Retrieval-by-complementarity (gap-fill, not look-alike) |
| Multi-model coordination | Embedding model → ranking model → LLM pitch generator, chained with feedback |
| AI copilot | Match → 3 buildable project pitches (the mission) |
| Makes work smarter | Surfaces teams that can actually ship |

**RedRob angle (the business win):** every swipe is a labeled human judgment of talent
complementarity. Mesh is a data flywheel that trains RedRob's enterprise
team-composition intelligence.

## 3. The core system — Complementarity Engine

Two stages + a feedback loop.

### Stage 1 — Retrieval (candidate generation)
- Each profile has a skill set with proficiency weights (`profile_skills.weight`) and a
  `skill_embedding vector(384)` (pgvector, already scaffolded).
- Compute the user's **gap profile**: which skill categories they're weak/absent in.
- Retrieve candidates who are **strong where the user is weak** AND share enough common
  ground to collaborate (orthogonal opposites can't communicate — this gating is the nuance).
- Filters: exclude self, already-swiped, inactive.

### Stage 2 — Ranking (the recsys)
Transparent, explainable weighted score per candidate (judge-friendly — we can show the "why"):

```
score(U, C) =
    w1 * complementarity(U, C)     # C's strengths ∩ U's gaps
  + w2 * shared_ground(U, C)       # overlap enough to work together
  + w3 * reciprocity(C → U)        # P(C swipes U back) — learned from swipe history
  + w4 * affinity(U → C)           # U's past right-swipe taste centroid
  + w5 * project_potential(U, C)   # historical match→collab rate for this skill pair
  - w6 * diversity_penalty(C)      # avoid showing the same archetype repeatedly
```

- **complementarity** = gap-fill score, gated by shared_ground.
- **reciprocity** = from `swipes`; cold-start prior = C's overall right-swipe rate + skill-pair affinity.
- **affinity** = centroid of skill-vectors U swiped right on → score C's closeness. (The "Instagram learns your taste" part.)
- Weights start hand-tuned (explainable); with more data, fit a logistic-regression on
  `(features → matched?)`.

### Stage 3 — Flywheel (data + live learning)
- Every swipe writes: `{swiper, target, direction, time_ms, deck_position, feature_vector_at_decision}`.
- **Online (cheap, per swipe):** update U's affinity centroid + C's reciprocity rate.
- **Offline (periodic):** retrain ranking weights.
- **RedRob value:** aggregate complementarity judgments = training data for enterprise
  team-composition models. "Which skill combinations humans judge as buildable teams."

### Multi-model coordination
1. Embedding model — skill set → vector (384-d)
2. Ranking model — feature vector → score
3. LLM pitch generator — Groq `llama-3.3-70b-versatile` (already live)

They chain: embeddings → retrieval → ranking → surface → match → LLM pitch →
**pitch confidence feeds back as a project_potential signal.** A genuine multi-model loop.

## 4. Demo script (live)

1. Show my profile (skills: HTML/TS/JS/Python — all code, no design).
2. Open deck → narrate: *"The engine isn't showing me more coders. Sara (illustrator)
   is #1 because she fills my visual gap and we share enough ground to ship."*
   **Each card shows a "why you're seeing this" chip** (explainability = wow moment).
3. Swipe right → match overlay → 3 AI pitches → "Say hi" → icebreaker auto-sent.
4. Flywheel slide: *"That swipe just trained the model. Here's the labeled data RedRob gets."*

## 5. Existing foundation (already built)

- Swipe deck UI, match overlay (gacha animation), chat, profile, feed
- Groq pitch engine (`POST /pitches`) — tested end-to-end
- `collab_pitches` table, chat icebreaker
- Supabase: `get_deck` + `record_swipe` RPCs (live in DB), `swipes` capturing `time_ms`
- 12 demo users with skills/weights/vibes

## 6. Open decisions (need input)

- [ ] **Embeddings vs. category-vectors for retrieval** — real sentence-transformer
      embeddings (impressive, uses pgvector) vs. transparent skill-category vectors
      (simpler, fully explainable). Recommendation: embeddings for retrieval, transparent
      math for ranking.
- [ ] **Where ranking lives** — Python FastAPI `/deck` endpoint (flexible, numpy/ML) vs.
      Supabase SQL RPC (current). Recommendation: move to Python backend.
- [ ] **Live online-learning in the demo** — show the model visibly adapting to swipes,
      or static-but-smart ranking? Online adaptation is a killer moment but more work.
- [ ] **"Why you're seeing this" explainability chip in the deck UI** — strong demo
      winner. Recommendation: yes.

## 7. Out of scope (for now)

- N-person team assembly (the "team compiler" stretch) — pairwise first.
- Real-time embeddings recompute on profile edit — batch is fine for demo.
- OAuth providers — email OTP works for demo.
