"""
One-time (re-runnable) script: populate skill + profile embeddings in Supabase.

Embeds every skill name into a 384-d vector and stores it on `skills.embedding`,
then computes each profile's vector as the proficiency-weighted average of its
skills and stores it on `profiles.skill_embedding`.

These vectors power the complementarity ranking engine (see ranking.py). This
runs offline — the live /deck endpoint only reads the vectors, so the demo never
depends on an embedding model being loaded at serve time.

Embedding backend (auto-detected):
  1. fastembed  — local, ONNX, no API key (preferred)
  2. Cohere     — embed-english-light-v3.0 (384-d) if COHERE_API_KEY is set

Run:
  cd backend && python embed_skills.py
"""

import os

from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

_db = create_client(
    os.environ["SUPABASE_URL"],
    os.environ["SUPABASE_SERVICE_ROLE_KEY"],
)

DIM = 384


# ── Embedding backend ─────────────────────────────────────────────────────────

def _get_embedder():
    """Returns embed(texts: list[str]) -> list[list[float]] (unit-normalized)."""
    try:
        from fastembed import TextEmbedding

        print("Using fastembed (local, all-MiniLM-L6-v2)...")
        model = TextEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")

        def embed(texts):
            return [_normalize(list(v)) for v in model.embed(texts)]

        return embed
    except Exception as e:  # noqa: BLE001 — fall back to API path
        print(f"fastembed unavailable ({e}); trying Cohere...")

    cohere_key = os.environ.get("COHERE_API_KEY")
    if cohere_key:
        import cohere

        print("Using Cohere (embed-english-light-v3.0)...")
        client = cohere.Client(cohere_key)

        def embed(texts):
            resp = client.embed(
                texts=texts,
                model="embed-english-light-v3.0",
                input_type="search_document",
            )
            return [_normalize(v) for v in resp.embeddings]

        return embed

    raise RuntimeError(
        "No embedding backend available. Either `pip install fastembed` "
        "succeeds, or set COHERE_API_KEY in backend/.env"
    )


def _normalize(vec):
    norm = sum(x * x for x in vec) ** 0.5 or 1.0
    return [x / norm for x in vec]


def _to_pg(vec) -> str:
    """pgvector accepts a bracketed string literal."""
    return "[" + ",".join(f"{x:.6f}" for x in vec) + "]"


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    embed = _get_embedder()

    # 1. Embed every skill.
    skills = _db.table("skills").select("id, name").execute().data
    print(f"Embedding {len(skills)} skills...")
    vectors = embed([s["name"] for s in skills])
    skill_vec = {}
    for s, v in zip(skills, vectors):
        skill_vec[s["id"]] = v
        _db.table("skills").update({"embedding": _to_pg(v)}).eq("id", s["id"]).execute()
    print("  skills done.")

    # 2. Profile vector = proficiency-weighted average of its skills' vectors.
    profiles = _db.table("profiles").select("id").execute().data
    print(f"Building {len(profiles)} profile vectors...")
    done = 0
    for p in profiles:
        rows = (
            _db.table("profile_skills")
            .select("skill_id, weight")
            .eq("profile_id", p["id"])
            .execute()
            .data
        )
        if not rows:
            continue
        acc = [0.0] * DIM
        total_w = 0.0
        for r in rows:
            v = skill_vec.get(r["skill_id"])
            if v is None:
                continue
            w = float(r["weight"])
            total_w += w
            for i in range(DIM):
                acc[i] += v[i] * w
        if total_w == 0:
            continue
        avg = _normalize([x / total_w for x in acc])
        _db.table("profiles").update(
            {"skill_embedding": _to_pg(avg)}
        ).eq("id", p["id"]).execute()
        done += 1
    print(f"  {done} profile vectors written.")
    print("Done.")


if __name__ == "__main__":
    main()
