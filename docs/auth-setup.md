# Mesh — Auth Provider Setup

The auth code supports **GitHub OAuth**, **Google OAuth**, and **email OTP**.
Each needs a one-time configuration in the Supabase dashboard.

Supabase project: `luourzpnaeeckaravaxl`
OAuth callback URL (used by every provider):
```
https://luourzpnaeeckaravaxl.supabase.co/auth/v1/callback
```

---

## 1. Email OTP (fastest — test the flow on Windows today)

Email OTP needs no OAuth app and no redirect, so it works on desktop.

1. Supabase → **Authentication → Email Templates → Magic Link**
2. Make sure the body includes the 6-digit code token. Paste this:
   ```html
   <h2>Your Mesh code</h2>
   <p>Enter this code to sign in:</p>
   <h1>{{ .Token }}</h1>
   ```
3. Save. Now `Send code` in the app emails a 6-digit code you type back in.

> Free tier sends a few emails/hour — fine for testing.

---

## 2. GitHub OAuth (the hero flow — powers skill auto-import)

1. GitHub → **Settings → Developer settings → OAuth Apps → New OAuth App**
   - **Application name:** Mesh
   - **Homepage URL:** `https://luourzpnaeeckaravaxl.supabase.co`
   - **Authorization callback URL:** `https://luourzpnaeeckaravaxl.supabase.co/auth/v1/callback`
2. **Register** → copy the **Client ID** → **Generate a new client secret** → copy it
3. Supabase → **Authentication → Providers → GitHub** → toggle **Enabled**,
   paste Client ID + Secret → **Save**

---

## 3. Google OAuth (universal sign-in)

1. [Google Cloud Console](https://console.cloud.google.com) → create a project
2. **APIs & Services → OAuth consent screen** → External → fill app name + email
3. **Credentials → Create Credentials → OAuth client ID → Web application**
   - **Authorized redirect URI:** `https://luourzpnaeeckaravaxl.supabase.co/auth/v1/callback`
4. Copy **Client ID** + **Client secret**
5. Supabase → **Authentication → Providers → Google** → enable, paste both → **Save**

---

## Platform notes

- **Web / Android:** OAuth redirects work out of the box.
- **Windows desktop:** OAuth redirect needs the `com.mesh.app://` URL scheme
  registered natively (not set up yet). Use **email OTP** on desktop for now;
  OAuth will be verified on Android.
