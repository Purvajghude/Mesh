"""
Connected accounts → proof-of-skill XP.

A generic framework: each provider knows how to (1) fetch public stats from a
handle and (2) map those stats to skill-XP grants. Connecting an account awards
the XP to the matching skills (creating them if new), so a builder's external
footprint becomes evidence-backed expertise in Mesh.

Adding a provider = add one entry to REGISTRY. Public-handle providers (GitHub,
Codeforces, LeetCode, Chess.com...) work today; OAuth providers (Strava, Spotify)
slot into the same shape once a token flow exists.
"""

from __future__ import annotations

import secrets
from datetime import datetime, timezone
from typing import Any

import httpx
from supabase import Client

import skills_api

# ── GitHub ───────────────────────────────────────────────────────────────────

# GitHub "languages" that aren't real skills — don't turn these into skills.
_GH_SKIP = {
    "Dockerfile", "Makefile", "CMake", "Batchfile", "Roff", "M4",
    "Procfile", "Gnuplot", "Smarty", "Mustache",
}
# Normalize GitHub language names to Mesh skill names.
_GH_LANG_MAP = {"Jupyter Notebook": "Python"}


def _github_fetch(handle: str) -> dict[str, Any]:
    headers = {
        "User-Agent": "mesh-app",
        "Accept": "application/vnd.github+json",
    }
    resp = httpx.get(
        f"https://api.github.com/users/{handle}/repos",
        params={"per_page": 100, "sort": "pushed", "type": "owner"},
        headers=headers,
        timeout=15,
    )
    if resp.status_code == 404:
        raise ValueError(f"GitHub user '{handle}' not found")
    if resp.status_code != 200:
        raise ValueError(f"GitHub API error ({resp.status_code}) — try again shortly")

    repos = resp.json()
    languages: dict[str, int] = {}
    stars = 0
    owned = 0
    for repo in repos:
        if repo.get("fork"):
            continue  # count original work only
        owned += 1
        stars += int(repo.get("stargazers_count", 0))
        lang = repo.get("language")
        if lang and lang not in _GH_SKIP:
            lang = _GH_LANG_MAP.get(lang, lang)
            languages[lang] = languages.get(lang, 0) + 1
    return {"languages": languages, "repos": owned, "stars": stars}


def _github_grants(stats: dict[str, Any]) -> list[tuple[str, float, str]]:
    grants: list[tuple[str, float, str]] = []
    for lang, count in stats["languages"].items():
        # Each public repo in a language is real evidence — 12 XP, capped at 60.
        grants.append((lang, min(60, count * 12), f"{count} GitHub repo(s)"))
    if stats["stars"] > 0:
        grants.append(
            ("Open Source", min(50, stats["stars"] * 2), f"{stats['stars']} stars")
        )
    return grants


def _github_summary(stats: dict[str, Any]) -> dict[str, Any]:
    return {
        "repos": stats["repos"],
        "stars": stats["stars"],
        "languages": list(stats["languages"].keys()),
    }


# ── Codeforces (official public API) ─────────────────────────────────────────

def _cf_fetch(handle: str) -> dict[str, Any]:
    base = "https://codeforces.com/api"
    info = httpx.get(f"{base}/user.info", params={"handles": handle}, timeout=15)
    j = info.json()
    if j.get("status") != "OK" or not j.get("result"):
        raise ValueError(f"Codeforces user '{handle}' not found")
    u = j["result"][0]
    solved = 0
    try:
        st = httpx.get(
            f"{base}/user.status",
            params={"handle": handle, "count": 10000},
            timeout=20,
        ).json()
        if st.get("status") == "OK":
            seen = set()
            for sub in st["result"]:
                if sub.get("verdict") == "OK":
                    p = sub.get("problem", {})
                    seen.add(f"{p.get('contestId')}-{p.get('index')}")
            solved = len(seen)
    except Exception:  # noqa: BLE001 — solved count is best-effort
        pass
    return {
        "rating": u.get("rating", 0),
        "maxRating": u.get("maxRating", 0),
        "rank": u.get("rank", "unrated"),
        "solved": solved,
    }


def _cf_grants(stats: dict[str, Any]) -> list[tuple[str, float, str]]:
    grants: list[tuple[str, float, str]] = []
    maxr = stats["maxRating"] or stats["rating"] or 0
    if maxr > 0:
        cp = min(100, max(5, round((maxr - 800) / 12)))
        grants.append(
            ("Competitive Programming", cp, f"CF max rating {maxr} ({stats['rank']})")
        )
    if stats["solved"] > 0:
        grants.append(
            ("Problem Solving", min(100, max(5, round(stats["solved"] / 3))),
             f"{stats['solved']} problems solved")
        )
    return grants


def _cf_summary(s: dict[str, Any]) -> dict[str, Any]:
    return {"rating": s["rating"], "maxRating": s["maxRating"],
            "rank": s["rank"], "solved": s["solved"]}


# ── LeetCode (unofficial GraphQL) ────────────────────────────────────────────

def _lc_fetch(handle: str) -> dict[str, Any]:
    query = (
        "query($u:String!){matchedUser(username:$u){"
        "submitStatsGlobal{acSubmissionNum{difficulty count}}}}"
    )
    resp = httpx.post(
        "https://leetcode.com/graphql",
        json={"query": query, "variables": {"u": handle}},
        headers={
            "Referer": "https://leetcode.com",
            "Content-Type": "application/json",
            "User-Agent": "mesh-app",
        },
        timeout=15,
    )
    data = (resp.json().get("data") or {}).get("matchedUser")
    if not data:
        raise ValueError(f"LeetCode user '{handle}' not found")
    counts = {
        x["difficulty"]: x["count"]
        for x in data["submitStatsGlobal"]["acSubmissionNum"]
    }
    return {
        "easy": counts.get("Easy", 0),
        "medium": counts.get("Medium", 0),
        "hard": counts.get("Hard", 0),
        "total": counts.get("All", 0),
    }


def _lc_grants(stats: dict[str, Any]) -> list[tuple[str, float, str]]:
    grants: list[tuple[str, float, str]] = []
    if stats["total"] > 0:
        grants.append(
            ("Problem Solving", min(100, max(5, round(stats["total"] / 3))),
             f"{stats['total']} LeetCode problems")
        )
        algo = min(100, max(5, round((stats["medium"] + stats["hard"] * 2) / 2)))
        grants.append(
            ("Algorithms", algo,
             f"{stats['medium']} medium + {stats['hard']} hard")
        )
    return grants


def _lc_summary(s: dict[str, Any]) -> dict[str, Any]:
    return {"solved": s["total"], "medium": s["medium"], "hard": s["hard"]}


# ── Chess.com (official public API) ──────────────────────────────────────────

def _chess_fetch(handle: str) -> dict[str, Any]:
    resp = httpx.get(
        f"https://api.chess.com/pub/player/{handle}/stats",
        headers={"User-Agent": "mesh-app"},
        timeout=15,
    )
    if resp.status_code == 404:
        raise ValueError(f"Chess.com user '{handle}' not found")
    if resp.status_code != 200:
        raise ValueError(f"Chess.com API error ({resp.status_code})")
    j = resp.json()

    def rating(key: str) -> int:
        return int((j.get(key, {}).get("last", {}) or {}).get("rating", 0))

    rapid, blitz, bullet = rating("chess_rapid"), rating("chess_blitz"), rating("chess_bullet")
    return {"rapid": rapid, "blitz": blitz, "bullet": bullet,
            "best": max(rapid, blitz, bullet)}


def _chess_grants(stats: dict[str, Any]) -> list[tuple[str, float, str]]:
    best = stats["best"]
    if best <= 0:
        return []
    return [("Strategy", min(100, max(5, round((best - 600) / 15))),
             f"Chess.com best rating {best}")]


def _chess_summary(s: dict[str, Any]) -> dict[str, Any]:
    return {"best": s["best"], "rapid": s["rapid"], "blitz": s["blitz"]}


# ── Ownership verification ───────────────────────────────────────────────────
# Each reader returns a lowercased blob of the account's *settable* public text,
# which we search for the user's one-time code to prove they own the handle.

def _gh_verify_text(handle: str) -> str:
    r = httpx.get(
        f"https://api.github.com/users/{handle}",
        headers={"User-Agent": "mesh-app", "Accept": "application/vnd.github+json"},
        timeout=15,
    )
    if r.status_code != 200:
        raise ValueError(f"GitHub user '{handle}' not found")
    j = r.json()
    return " ".join(str(j.get(k) or "") for k in ("bio", "name", "company")).lower()


def _cf_verify_text(handle: str) -> str:
    j = httpx.get(
        "https://codeforces.com/api/user.info",
        params={"handles": handle}, timeout=15,
    ).json()
    if j.get("status") != "OK" or not j.get("result"):
        raise ValueError(f"Codeforces user '{handle}' not found")
    u = j["result"][0]
    return " ".join(
        str(u.get(k) or "") for k in ("firstName", "lastName", "organization")
    ).lower()


def _lc_verify_text(handle: str) -> str:
    query = "query($u:String!){matchedUser(username:$u){profile{aboutMe realName}}}"
    r = httpx.post(
        "https://leetcode.com/graphql",
        json={"query": query, "variables": {"u": handle}},
        headers={"Referer": "https://leetcode.com", "Content-Type": "application/json",
                 "User-Agent": "mesh-app"},
        timeout=15,
    )
    mu = (r.json().get("data") or {}).get("matchedUser")
    if not mu:
        raise ValueError(f"LeetCode user '{handle}' not found")
    p = mu.get("profile") or {}
    return " ".join(str(p.get(k) or "") for k in ("aboutMe", "realName")).lower()


def _chess_verify_text(handle: str) -> str:
    r = httpx.get(
        f"https://api.chess.com/pub/player/{handle}",
        headers={"User-Agent": "mesh-app"}, timeout=15,
    )
    if r.status_code != 200:
        raise ValueError(f"Chess.com user '{handle}' not found")
    j = r.json()
    return " ".join(str(j.get(k) or "") for k in ("name", "location")).lower()


# ── Registry ─────────────────────────────────────────────────────────────────

Provider = dict[str, Any]

REGISTRY: dict[str, Provider] = {
    "github": {
        "label": "GitHub", "fetch": _github_fetch, "grants": _github_grants,
        "summary": _github_summary, "verify_text": _gh_verify_text,
        "verify_field": "your GitHub bio",
    },
    "codeforces": {
        "label": "Codeforces", "fetch": _cf_fetch, "grants": _cf_grants,
        "summary": _cf_summary, "verify_text": _cf_verify_text,
        "verify_field": "your Codeforces first-name field",
    },
    "leetcode": {
        "label": "LeetCode", "fetch": _lc_fetch, "grants": _lc_grants,
        "summary": _lc_summary, "verify_text": _lc_verify_text,
        "verify_field": "your LeetCode Summary (About)",
    },
    "chesscom": {
        "label": "Chess.com", "fetch": _chess_fetch, "grants": _chess_grants,
        "summary": _chess_summary, "verify_text": _chess_verify_text,
        "verify_field": "your Chess.com name or location",
    },
    # OAuth providers (need a token flow): "strava", "spotify"
}


def make_challenge(db: Client, user_id: str, provider: str) -> dict[str, Any]:
    """Issue a one-time code the user must place in their platform profile to
    prove ownership before connecting."""
    prov = REGISTRY.get(provider)
    if prov is None:
        raise ValueError(f"Unknown provider: {provider}")
    nonce = "mesh-" + secrets.token_hex(4)
    db.table("connected_accounts").upsert(
        {
            "profile_id": user_id, "provider": provider, "handle": "",
            "verify_nonce": nonce, "verified": False,
        },
        on_conflict="profile_id,provider",
    ).execute()
    return {"nonce": nonce, "field": prov["verify_field"], "label": prov["label"]}


# ── Orchestration ────────────────────────────────────────────────────────────

def connect_account(
    db: Client, user_id: str, provider: str, handle: str
) -> dict[str, Any]:
    prov = REGISTRY.get(provider)
    if prov is None:
        raise ValueError(f"Unknown provider: {provider}")
    handle = (handle or "").strip().lstrip("@")
    if not handle:
        raise ValueError("A handle/username is required")

    # Prior connection state: XP baseline + whether ownership is already proven.
    existing = (
        db.table("connected_accounts")
        .select("granted_xp, verified, verify_nonce")
        .eq("profile_id", user_id)
        .eq("provider", provider)
        .execute()
        .data
    )
    row = existing[0] if existing else None

    # Prove handle ownership (skip if already verified for this provider).
    if not (row and row.get("verified")):
        nonce = row.get("verify_nonce") if row else None
        if not nonce:
            raise ValueError("Request a verification code first.")
        if nonce.lower() not in prov["verify_text"](handle):
            raise ValueError(
                f"Couldn't find {nonce} in {prov['verify_field']}. "
                "Add it (you can remove it afterwards), then verify."
            )

    stats = prov["fetch"](handle)

    # Aggregate grants by skill (sum collisions, e.g. Jupyter→Python).
    new_granted: dict[str, float] = {}
    reasons: dict[str, str] = {}
    for skill_name, points, reason in prov["grants"](stats):
        new_granted[skill_name] = new_granted.get(skill_name, 0) + float(points)
        reasons.setdefault(skill_name, reason)

    # Re-sync only awards the positive delta, so XP never double-counts.
    prev = (row.get("granted_xp") if row else {}) or {}

    awarded: list[dict[str, Any]] = []
    for skill_name, points in new_granted.items():
        delta = points - float(prev.get(skill_name, 0))
        if delta <= 0:
            continue
        skill_id, _ = skills_api._find_or_create_skill(db, skill_name)
        db.rpc(
            "award_skill_xp",
            {
                "p_profile": user_id,
                "p_skill": skill_id,
                "p_source": "integration",
                "p_points": delta,
                "p_ref": f"{provider}:{handle}",
            },
        ).execute()
        awarded.append(
            {"skill": skill_name, "xp": round(delta, 1), "why": reasons[skill_name]}
        )

    skills_api._recompute_profile_vector(db, user_id)

    db.table("connected_accounts").upsert(
        {
            "profile_id": user_id,
            "provider": provider,
            "handle": handle,
            "stats": stats,
            "granted_xp": new_granted,
            "verified": True,
            "verify_nonce": None,
            "last_synced_at": datetime.now(timezone.utc).isoformat(),
        },
        on_conflict="profile_id,provider",
    ).execute()

    return {
        "provider": provider,
        "label": prov["label"],
        "handle": handle,
        "summary": prov["summary"](stats),
        "awarded": awarded,
    }


def list_accounts(db: Client, user_id: str) -> list[dict[str, Any]]:
    rows = (
        db.table("connected_accounts")
        .select("provider, handle, last_synced_at")
        .eq("profile_id", user_id)
        .execute()
        .data
        or []
    )
    return rows


def available_providers() -> list[dict[str, Any]]:
    return [{"provider": k, "label": v["label"]} for k, v in REGISTRY.items()]
