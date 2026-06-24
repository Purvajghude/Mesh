# Deploying the Mesh AI backend

The Flutter app talks straight to Supabase for almost everything; only the
**Groq-powered AI** (pitches, skill add/craft, AI feed first-pass, moderation)
needs this backend. Deploying it means the app's AI works without your laptop or
a tunnel.

Files already scaffolded: [`backend/Dockerfile`](backend/Dockerfile),
[`backend/.dockerignore`](backend/.dockerignore), [`render.yaml`](render.yaml).

## What you need (3 secrets)
Copy them from your local `backend/.env`:
- `SUPABASE_URL` — `https://luourzpnaeeckaravaxl.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY` — Supabase → Project Settings → API → **service_role** key
- `GROQ_API_KEY` — your Groq console key

> The service-role key is admin-level — it lives **only** in the host's env vars,
> never in the app or git. The backend is internet-facing but every real endpoint
> is gated by a Supabase JWT (verified server-side), so a public URL is fine.

## Deploy on Render (recommended)
1. Push this repo to GitHub (if it isn't already).
2. Render → **New → Blueprint** → pick the repo. It reads `render.yaml` and builds
   `backend/Dockerfile`.
3. When prompted, paste the **3 secrets** above.
4. Create → wait for the first build (~3–5 min; it bakes the embedding model in).
5. You get a URL like `https://mesh-ai-backend.onrender.com`. Verify:
   ```
   curl https://mesh-ai-backend.onrender.com/health        # -> {"status":"ok"}
   ```

## Point the app at it
Two options:
- **No rebuild:** in the app → **You** tab → **AI backend** → paste the Render URL.
- **Bake it in:** rebuild the APK so testers need no setup:
  ```
  flutter build apk --release --dart-define=API_BASE_URL=https://mesh-ai-backend.onrender.com
  ```

## Caveats
- **Free tier spins down** after ~15 min idle → first request after that is a
  ~30–60s cold start (the model is baked in, so no download). For a smooth live
  demo, use the **Starter** plan (no spin-down).
- **fastembed is RAM-heavy.** The Groq feed-AI features run fine on free; if
  **skill add/craft** errors out (OOM), bump `plan: free` → `starter` in
  `render.yaml`.
- Same `Dockerfile` works on **Railway** or **Fly.io** if you prefer — just set
  the same 3 env vars and expose `$PORT`.
