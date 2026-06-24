# Mesh AI backend — FastAPI (Groq + lazy fastembed).
# Python 3.12 for the broadest Linux wheel availability (onnxruntime/fastembed).
FROM python:3.12-slim

# onnxruntime (used by fastembed) needs libgomp at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps first so the layer caches across code changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Bake the embedding model into the image so cold starts never download it
# (only the skill add/craft path uses it; the rest just calls Groq).
RUN python -c "from fastembed import TextEmbedding; TextEmbedding(model_name='sentence-transformers/all-MiniLM-L6-v2')"

# App code.
COPY . .

# PaaS hosts inject $PORT; default 8000 for plain `docker run`.
ENV PORT=8000
EXPOSE 8000
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
