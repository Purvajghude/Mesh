"""
Mesh Complementarity Ranking Engine.

Given a user and a pool of candidate builders, score and order the swipe deck by
how likely each pairing is to become a productive collaboration — optimizing for
COMPLEMENTARITY (gap-filling skills), not similarity.

Score per candidate:
    score = W_COMPLEMENT * complement_fit   # their strengths fill my gaps,
            + W_RECIPROCITY * reciprocity    #   gated by shared ground
            + W_AFFINITY    * affinity        # my learned taste (updates as I swipe)
Then a diversity pass demotes near-duplicate archetypes so the deck stays varied.

All math is pure Python over unit-normalized vectors (cosine == dot product), so
the live endpoint has no heavyweight ML dependency — embeddings are precomputed
offline by embed_skills.py and just read from the DB.
"""

from __future__ import annotations

# ── Tunable weights (explainable on purpose — we show judges the "why") ──────
W_COMPLEMENT = 0.60   # the star signal: do they fill my gaps?
W_RECIPROCITY = 0.20  # will they likely swipe me back?
W_AFFINITY = 0.20     # my demonstrated taste, learned from past right-swipes

# Cosine-sim threshold at which two skills count as "shared ground". Sentence
# embeddings sit fairly high for short text, so this is calibrated, not 0.
SHARED_GROUND_FULL = 0.55  # sim at/above this = fully connectable
DEMO_RECIPROCITY_PRIOR = 0.70  # demo users like back ~70% (see record_swipe RPC)
DIVERSITY_SIM = 0.80  # candidates this similar to a higher-ranked one get demoted


def _dot(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def _novelty_and_share(
    my_skills: list[dict],
    cand_skills: list[dict],
    vecs: dict[str, list[float]],
) -> tuple[float, float, str, str]:
    """Returns (complementarity, shared_ground, novel_skill_name, shared_skill_name).

    complementarity — proficiency-weighted average, over the candidate's skills,
        of how semantically far each is from my nearest skill (1 - max_sim).
    shared_ground   — the single closest skill pair between us (max cosine).
    """
    my_vecs = [(s["name"], vecs[s["skill_id"]]) for s in my_skills if s["skill_id"] in vecs]
    if not my_vecs:
        return 0.0, 0.0, "", ""

    total_w = 0.0
    weighted_novelty = 0.0
    best_novel = (-1.0, "")   # (novelty * weight, skill name) — what they uniquely add
    best_shared = (-1.0, "")  # (sim, skill name) — our closest common ground

    for cs in cand_skills:
        cv = vecs.get(cs["skill_id"])
        if cv is None:
            continue
        w = float(cs["weight"])
        max_sim = max(_dot(cv, mv) for _, mv in my_vecs)
        novelty = 1.0 - max_sim
        weighted_novelty += novelty * w
        total_w += w

        if novelty * w > best_novel[0]:
            best_novel = (novelty * w, cs["name"])
        if max_sim > best_shared[0]:
            best_shared = (max_sim, cs["name"])

    if total_w == 0:
        return 0.0, 0.0, "", ""

    complementarity = weighted_novelty / total_w
    shared_ground = max(0.0, best_shared[0])
    return complementarity, shared_ground, best_novel[1], best_shared[1]


def _complement_fit(complementarity: float, shared_ground: float) -> float:
    """High when a candidate is complementary AND connectable.

    A gate scales complementarity down when there's no common ground — pure
    opposites can't actually collaborate.
    """
    gate = min(1.0, shared_ground / SHARED_GROUND_FULL) if SHARED_GROUND_FULL else 1.0
    gate = 0.35 + 0.65 * gate  # never fully zero, but strongly rewarded
    return complementarity * gate


def _explanation(novel: str, shared: str, shared_ground: float) -> str:
    """The 'why you're seeing this' chip.

    Only claims common ground when overlap is genuinely high — most strong
    matches are pure complementarity (low overlap), so we lead with what the
    candidate uniquely brings."""
    if novel and shared and shared != novel and shared_ground >= 0.60:
        return f"brings {novel} · you connect through {shared}"
    if novel:
        return f"brings {novel} — fills a gap in your stack"
    return "complements your skill set"


def score_deck(
    me: dict,
    candidates: list[dict],
    skill_vecs: dict[str, list[float]],
    reciprocity: dict[str, float],
    taste_centroid: list[float] | None,
) -> list[dict]:
    """Score, explain, and order candidates.

    me / candidates: {id, username, display_name, vibe_statement, avatar_config,
                      reputation, profile_vec, skills:[{skill_id,name,weight}]}
    reciprocity: candidate_id -> P(swipes me back)
    taste_centroid: unit vector averaging profiles I've right-swiped (or None).
    """
    scored = []
    for c in candidates:
        comp, shared, novel_name, shared_name = _novelty_and_share(
            me["skills"], c["skills"], skill_vecs
        )
        fit = _complement_fit(comp, shared)

        recip = reciprocity.get(c["id"], DEMO_RECIPROCITY_PRIOR)

        if taste_centroid and c.get("profile_vec"):
            affinity = max(0.0, _dot(taste_centroid, c["profile_vec"]))
        else:
            affinity = 0.5  # neutral until the user has swiped

        score = (
            W_COMPLEMENT * fit
            + W_RECIPROCITY * recip
            + W_AFFINITY * affinity
        )

        scored.append({
            **{k: c[k] for k in (
                "id", "username", "display_name", "vibe_statement",
                "avatar_config", "reputation", "skills",
            ) if k in c},
            "profile_vec": c.get("profile_vec"),
            "score": round(score, 4),
            "explanation": _explanation(novel_name, shared_name, shared),
            "breakdown": {
                "complementarity": round(comp, 3),
                "shared_ground": round(shared, 3),
                "complement_fit": round(fit, 3),
                "reciprocity": round(recip, 3),
                "affinity": round(affinity, 3),
            },
        })

    scored.sort(key=lambda x: x["score"], reverse=True)
    scored = _diversify(scored)
    # Strip the internal vector before returning to the client.
    for s in scored:
        s.pop("profile_vec", None)
    return scored


def _diversify(scored: list[dict]) -> list[dict]:
    """Greedy re-rank: demote a candidate too similar to one already placed,
    so the deck doesn't show five of the same archetype in a row."""
    if len(scored) <= 2:
        return scored
    placed: list[dict] = []
    pool = scored[:]
    while pool:
        best_i, best_adj = 0, -1e9
        for i, cand in enumerate(pool):
            penalty = 0.0
            cv = cand.get("profile_vec")
            if cv:
                for p in placed:
                    pv = p.get("profile_vec")
                    if pv:
                        sim = _dot(cv, pv)
                        if sim > DIVERSITY_SIM:
                            penalty = max(penalty, (sim - DIVERSITY_SIM) * 0.5)
            adj = cand["score"] - penalty
            if adj > best_adj:
                best_adj, best_i = adj, i
        placed.append(pool.pop(best_i))
    return placed
