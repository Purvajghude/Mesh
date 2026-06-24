"""
Deck assembly — fetches the data the ranking engine needs and returns an ordered,
explained swipe deck for a given user.

Stage 1 (retrieval): pull candidate builders (onboarded, not me, not yet swiped),
                      with their skills and precomputed profile vectors.
Stage 2 (ranking):    hand off to ranking.score_deck for complementarity scoring.

Behavioral signals (reciprocity, taste centroid) are read from the `swipes` table,
so the deck reflects what the user has done — and shifts as they keep swiping.
"""

from __future__ import annotations

from typing import Any

from supabase import Client

import ranking

# Per-skill vectors are tiny and immutable during a run — cache them.
_skill_vec_cache: dict[str, list[float]] | None = None


def _parse_vec(raw: Any) -> list[float] | None:
    """PostgREST returns a pgvector as a '[0.1,0.2,...]' string (or a list)."""
    if raw is None:
        return None
    if isinstance(raw, list):
        return [float(x) for x in raw]
    s = str(raw).strip().lstrip("[").rstrip("]")
    if not s:
        return None
    return [float(x) for x in s.split(",")]


def invalidate_skill_cache() -> None:
    """Drop the per-skill vector cache so a newly added/crafted skill is picked
    up on the next deck build."""
    global _skill_vec_cache
    _skill_vec_cache = None


def load_skill_vecs(db: Client) -> dict[str, list[float]]:
    global _skill_vec_cache
    if _skill_vec_cache is not None:
        return _skill_vec_cache
    rows = db.table("skills").select("id, embedding").execute().data or []
    cache: dict[str, list[float]] = {}
    for r in rows:
        v = _parse_vec(r.get("embedding"))
        if v is not None:
            cache[r["id"]] = v
    _skill_vec_cache = cache
    return cache


def _skill_level(weight: float) -> int:
    """Proficiency weight (0..1) → a 1–5 mastery level for display."""
    return max(1, min(5, round(weight * 5)))


def _skills_for(db: Client, profile_ids: list[str]) -> dict[str, list[dict]]:
    """profile_id -> [{skill_id, name, weight, xp, level}] for many profiles."""
    if not profile_ids:
        return {}
    rows = (
        db.table("profile_skills")
        .select("profile_id, skill_id, weight, xp, skills(name)")
        .in_("profile_id", profile_ids)
        .execute()
        .data
        or []
    )
    out: dict[str, list[dict]] = {}
    for r in rows:
        if not r.get("skills"):
            continue
        weight = float(r["weight"])
        out.setdefault(r["profile_id"], []).append({
            "skill_id": r["skill_id"],
            "name": r["skills"]["name"],
            "weight": weight,
            "xp": float(r.get("xp") or 0),
            "level": _skill_level(weight),
        })
    return out


def _get_me(db: Client, user_id: str) -> dict:
    prof = (
        db.table("profiles")
        .select("id, username, display_name, vibe_statement, skill_embedding")
        .eq("id", user_id)
        .single()
        .execute()
        .data
    )
    if not prof:
        raise ValueError(f"Profile not found: {user_id}")
    prof["profile_vec"] = _parse_vec(prof.pop("skill_embedding", None))
    prof["skills"] = _skills_for(db, [user_id]).get(user_id, [])
    return prof


def _get_candidates(db: Client, user_id: str) -> list[dict]:
    swiped = (
        db.table("swipes")
        .select("target_id")
        .eq("swiper_id", user_id)
        .execute()
        .data
        or []
    )
    exclude = {row["target_id"] for row in swiped}
    exclude.add(user_id)

    q = (
        db.table("profiles")
        .select(
            "id, username, display_name, vibe_statement, avatar_config, "
            "reputation, skill_embedding"
        )
        .eq("onboarded", True)
    )
    rows = q.execute().data or []
    cands = [r for r in rows if r["id"] not in exclude]

    skills_by_id = _skills_for(db, [c["id"] for c in cands])
    for c in cands:
        c["profile_vec"] = _parse_vec(c.pop("skill_embedding", None))
        c["skills"] = skills_by_id.get(c["id"], [])
    # Only consider builders who actually have skills to reason about.
    return [c for c in cands if c["skills"]]


def _reciprocity(db: Client, candidate_ids: list[str]) -> dict[str, float]:
    """P(candidate swipes the user back), from each candidate's own swipe history.

    Cold-start (few/no outgoing swipes) falls back to the demo prior — demo users
    like back ~70% by design (see the record_swipe RPC)."""
    out: dict[str, float] = {}
    if not candidate_ids:
        return out
    rows = (
        db.table("swipes")
        .select("swiper_id, direction")
        .in_("swiper_id", candidate_ids)
        .execute()
        .data
        or []
    )
    tally: dict[str, list[int]] = {}
    for r in rows:
        right = 1 if r["direction"] in ("right", "up") else 0
        t = tally.setdefault(r["swiper_id"], [0, 0])
        t[0] += right
        t[1] += 1
    for cid in candidate_ids:
        rights, total = tally.get(cid, [0, 0])
        out[cid] = (rights / total) if total >= 3 else ranking.DEMO_RECIPROCITY_PRIOR
    return out


def _taste_centroid(db: Client, user_id: str) -> list[float] | None:
    """Unit-averaged profile vector of everyone the user has right/up-swiped.

    This is the user's learned taste — it updates with every right-swipe, which
    is what makes the deck visibly adapt during the demo."""
    liked = (
        db.table("swipes")
        .select("target_id, direction")
        .eq("swiper_id", user_id)
        .in_("direction", ["right", "up"])
        .execute()
        .data
        or []
    )
    target_ids = [r["target_id"] for r in liked]
    if not target_ids:
        return None
    rows = (
        db.table("profiles")
        .select("id, skill_embedding")
        .in_("id", target_ids)
        .execute()
        .data
        or []
    )
    vecs = [v for v in (_parse_vec(r.get("skill_embedding")) for r in rows) if v]
    if not vecs:
        return None
    dim = len(vecs[0])
    acc = [0.0] * dim
    for v in vecs:
        for i in range(dim):
            acc[i] += v[i]
    norm = sum(x * x for x in acc) ** 0.5 or 1.0
    return [x / norm for x in acc]


def build_deck(db: Client, user_id: str, limit: int = 20) -> list[dict]:
    skill_vecs = load_skill_vecs(db)
    me = _get_me(db, user_id)
    candidates = _get_candidates(db, user_id)
    if not candidates:
        return []
    reciprocity = _reciprocity(db, [c["id"] for c in candidates])
    taste = _taste_centroid(db, user_id)
    ranked = ranking.score_deck(me, candidates, skill_vecs, reciprocity, taste)
    return ranked[:limit]
