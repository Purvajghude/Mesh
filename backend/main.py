"""
Mesh AI Backend — FastAPI app exposing the /pitches endpoint.

Run locally:
  cd backend
  pip install -r requirements.txt
  cp .env.example .env  # fill in your keys
  uvicorn main:app --reload --port 8000
"""

import asyncio
import os
from typing import Any

import httpx
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address
from supabase import Client, create_client

import deck as deck_engine
import feed_ai
import integrations
import portfolio as portfolio_engine
import skills_api
from engine import generate_pitches

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

_db: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

app = FastAPI(title="Mesh AI Engine", version="0.1.0")

# Rate limiting (keyed by client IP) to protect the expensive AI endpoints from
# spam / cost-abuse. Limits are applied per-endpoint via @limiter.limit below.
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)


# ── Auth ─────────────────────────────────────────────────────────────────────

async def current_user(authorization: str | None = Header(default=None)) -> str:
    """Verify the caller's Supabase access token and return their user id.

    The acting user is ALWAYS derived from the verified token — never from a
    request body. This is the single control that stops one user acting as
    another (the backend holds the RLS-bypassing service-role key)."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                f"{SUPABASE_URL}/auth/v1/user",
                headers={"Authorization": f"Bearer {token}", "apikey": SUPABASE_KEY},
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail="Auth check failed") from exc
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    uid = resp.json().get("id")
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid token")
    return uid


# ── Models ───────────────────────────────────────────────────────────────────
# Note: no model carries user_id — the acting user comes from the token.

class PitchRequest(BaseModel):
    match_id: str
    force_refresh: bool = False


class AddSkillRequest(BaseModel):
    name: str


class CraftRequest(BaseModel):
    skill_ids: list[str]


class ChallengeRequest(BaseModel):
    provider: str


class ConnectRequest(BaseModel):
    provider: str
    handle: str


class PortfolioRequest(BaseModel):
    title: str
    description: str = ""
    images_b64: list[str] = []      # raw base64 JPEGs — judged then discarded
    links: list[str] = []
    capture_mode: str = "upload"    # 'camera' (full XP) | 'upload' (reduced)


class PostActionRequest(BaseModel):
    post_id: str


# ── Supabase helpers (sync; called via asyncio.to_thread) ────────────────────

def _fetch_profile_with_skills(user_id: str) -> dict[str, Any]:
    profile = (
        _db.table("profiles")
        .select("id, username, display_name, vibe_statement")
        .eq("id", user_id)
        .single()
        .execute()
    )
    if not profile.data:
        raise ValueError(f"Profile not found: {user_id}")

    skill_rows = (
        _db.table("profile_skills")
        .select("weight, skills(name, category)")
        .eq("profile_id", user_id)
        .execute()
    )
    skills = [
        {"name": row["skills"]["name"], "weight": row["weight"]}
        for row in (skill_rows.data or [])
        if row.get("skills")
    ]
    return {**profile.data, "skills": skills}


# ── Routes ───────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/deck")
async def get_deck(limit: int = 20, uid: str = Depends(current_user)):
    """The complementarity-ranked swipe deck for the authenticated user.

    Returns profiles ordered by collaboration potential, each with an
    `explanation` (the 'why you're seeing this' chip) and a score `breakdown`.
    """
    try:
        ranked = await asyncio.to_thread(deck_engine.build_deck, _db, uid, limit)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"deck": ranked}


@app.post("/profile/skills")
@limiter.limit("20/minute")
async def add_skill(
    request: Request, req: AddSkillRequest, uid: str = Depends(current_user)
):
    """Add any skill to your profile — open vocabulary, embedded on the fly."""
    try:
        skill = await asyncio.to_thread(
            skills_api.add_skill_to_profile, _db, uid, req.name
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return skill


@app.post("/craft")
@limiter.limit("10/minute")
async def craft(
    request: Request, req: CraftRequest, uid: str = Depends(current_user)
):
    """Combine two or more of your leveled skills into a compound skill."""
    try:
        result = await asyncio.to_thread(
            skills_api.craft_skill, _db, uid, req.skill_ids
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@app.get("/skills/{skill_id}/components")
async def get_skill_components(skill_id: str, uid: str = Depends(current_user)):
    """The atomic skills a compound is crafted from (drill-down view)."""
    return await asyncio.to_thread(
        skills_api.skill_components, _db, uid, skill_id
    )


@app.get("/integrations/providers")
async def integration_providers():
    """The connectable providers (for the UI to render)."""
    return {"providers": integrations.available_providers()}


@app.get("/integrations")
async def integration_list(uid: str = Depends(current_user)):
    """Your currently connected accounts."""
    rows = await asyncio.to_thread(integrations.list_accounts, _db, uid)
    return {"accounts": rows}


@app.post("/integrations/challenge")
async def integration_challenge(req: ChallengeRequest, uid: str = Depends(current_user)):
    """Issue a one-time code to place in your platform profile to prove ownership."""
    try:
        return await asyncio.to_thread(
            integrations.make_challenge, _db, uid, req.provider
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/integrations/connect")
@limiter.limit("10/minute")
async def integration_connect(
    request: Request, req: ConnectRequest, uid: str = Depends(current_user)
):
    """Verify ownership, then fetch public stats → award proof-of-skill XP."""
    try:
        result = await asyncio.to_thread(
            integrations.connect_account, _db, uid, req.provider, req.handle
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@app.get("/portfolio")
async def portfolio_list(uid: str = Depends(current_user)):
    """Your portfolio evidence entries."""
    rows = await asyncio.to_thread(portfolio_engine.list_evidence, _db, uid)
    return {"evidence": rows}


@app.post("/portfolio/submit")
@limiter.limit("5/minute")
async def portfolio_submit(
    request: Request, req: PortfolioRequest, uid: str = Depends(current_user)
):
    """Submit portfolio evidence → a vision model judges it → awards skill XP."""
    try:
        result = await asyncio.to_thread(
            portfolio_engine.submit_evidence,
            _db, uid, req.title, req.description,
            req.images_b64, req.links, req.capture_mode,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return result


@app.post("/asks/ai-answer")
@limiter.limit("15/minute")
async def ask_ai_answer(
    request: Request, req: PostActionRequest, uid: str = Depends(current_user)
):
    """Generate (and store) an instant AI first-pass answer on your ask."""
    try:
        return await asyncio.to_thread(
            feed_ai.generate_ask_answer, _db, req.post_id, uid
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/feed/moderate")
@limiter.limit("30/minute")
async def feed_moderate(
    request: Request, req: PostActionRequest, uid: str = Depends(current_user)
):
    """Quality + safety gate for one of your posts (flag-don't-block, fail-open)."""
    try:
        return await asyncio.to_thread(
            feed_ai.moderate_post, _db, req.post_id, uid
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.post("/pitches")
@limiter.limit("10/minute")
async def pitches(
    request: Request, req: PitchRequest, uid: str = Depends(current_user)
):
    # Verify the caller is actually in this match before doing anything.
    match_resp = (
        _db.table("matches")
        .select("id, user_a, user_b")
        .eq("id", req.match_id)
        .single()
        .execute()
    )
    if not match_resp.data:
        raise HTTPException(status_code=404, detail="Match not found")
    match = match_resp.data
    if uid not in (match["user_a"], match["user_b"]):
        raise HTTPException(status_code=403, detail="Not a participant in this match")

    # Return latest cached result unless caller wants a fresh roll.
    if not req.force_refresh:
        cached = (
            _db.table("collab_pitches")
            .select("pitches")
            .eq("match_id", req.match_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        if cached.data:
            return {"pitches": cached.data[0]["pitches"], "cached": True}

    # Fetch both profiles (with skills) in parallel.
    try:
        user_a, user_b = await asyncio.gather(
            asyncio.to_thread(_fetch_profile_with_skills, match["user_a"]),
            asyncio.to_thread(_fetch_profile_with_skills, match["user_b"]),
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    # Ask Claude for 3 pitches.
    pitch_list = await generate_pitches(user_a, user_b)

    # Cache — each call creates a new row so re-roll history is preserved.
    _db.table("collab_pitches").insert(
        {
            "match_id": req.match_id,
            "user_a_id": match["user_a"],
            "user_b_id": match["user_b"],
            "pitches": pitch_list,
        }
    ).execute()

    return {"pitches": pitch_list, "cached": False}
