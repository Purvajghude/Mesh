"""
Lazy embedding model shared by the skill-mutation endpoints (add / craft).

The model loads on first use, not at import — so the hot path (/deck) never
pays for it, and the server starts instantly. Embeddings produced here are
unit-normalized 384-d vectors matching the offline batch (embed_skills.py),
so a skill added live is directly comparable to the seeded ones.
"""

from __future__ import annotations

_model = None


def _get_model():
    global _model
    if _model is None:
        from fastembed import TextEmbedding

        _model = TextEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")
    return _model


def _normalize(vec: list[float]) -> list[float]:
    norm = sum(x * x for x in vec) ** 0.5 or 1.0
    return [x / norm for x in vec]


def embed_one(text: str) -> list[float]:
    """Embed a single piece of text → unit-normalized 384-d vector."""
    model = _get_model()
    vec = list(next(iter(model.embed([text]))))
    return _normalize([float(x) for x in vec])


def to_pg(vec: list[float]) -> str:
    """pgvector accepts a bracketed string literal."""
    return "[" + ",".join(f"{x:.6f}" for x in vec) + "]"
