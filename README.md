# Mesh 🧩

**Find people whose skills fit yours.** A skill-matching app — swipe on builders by their skills (not looks), match, chat, and collaborate. Flutter app + Supabase backend.

> New to coding? **Don't panic.** This guide walks you through *everything* step by step. Just follow it top to bottom. If something breaks, jump to [Troubleshooting](#-troubleshooting) at the bottom.

---

## 📋 What you'll install (one-time, ~30–45 min)

You need 4 things. Install them in this order:

| # | Tool | What it's for | Download |
|---|------|---------------|----------|
| 1 | **Git** | Downloads & syncs the code | https://git-scm.com/downloads |
| 2 | **Flutter SDK** | Builds & runs the app | https://docs.flutter.dev/get-started/install |
| 3 | **Android Studio** | Phone emulator + Android tools | https://developer.android.com/studio |
| 4 | **VS Code** | Where you write code | https://code.visualstudio.com/ |

> 💡 On **Windows**, Flutter can also run the app as a desktop window (no phone needed) — easiest way to test. On **Mac**, you can run it as an iOS simulator.

### After installing, in VS Code add these extensions
Open VS Code → click the Extensions icon (left bar) → search & install: **Flutter**, **Dart**.

---

## ✅ Step 1 — Check Flutter is working

Open a terminal (Windows: "Command Prompt" or "PowerShell"; Mac: "Terminal") and run:

```bash
flutter doctor
```

You want green checkmarks for **Flutter** and **Android toolchain**. If Android shows a ❌ about "licenses", run:

```bash
flutter doctor --android-licenses
```

…and press `y` + Enter for each prompt until it says "All SDK package licenses accepted."

> Don't worry if "Visual Studio" or "Xcode" show warnings — you only need those for desktop/iOS builds.

---

## ✅ Step 2 — Get the code

Ask the team lead (Purvaj) to **add you as a collaborator** on the private GitHub repo (they do this on github.com → repo → Settings → Collaborators → add your GitHub username). You'll get an email invite — accept it.

Then, in your terminal, go to where you keep projects and run:

```bash
git clone https://github.com/Purvajghude/Mesh.git
cd Mesh
```

---

## ✅ Step 3 — Add the secret keys (`.env`)

The app needs API keys to talk to the backend. These are **NOT** in the repo (for security). You'll get them from the team lead.

1. In the `Mesh` folder, you'll see a file called `.env.example`.
2. Make a **copy** of it and rename the copy to exactly `.env`
3. Open `.env` and paste in the real values the team lead sends you (in your team chat).

It should look like this (with the real values filled in):

```
SUPABASE_URL=https://xxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGci....(long string)
```

> ⚠️ Never share `.env` publicly or commit it to git. It's already ignored by git, so you can't accidentally push it.

---

## ✅ Step 4 — Install the app's packages

In the `Mesh` folder, run:

```bash
flutter pub get
```

This downloads all the libraries the app uses. Do this **every time** someone adds a new package (you'll know because the app won't build until you do).

---

## ✅ Step 5 — Run the app! 🎉

**Easiest (Windows):** run it as a desktop window. You need "Developer Mode" on once:
- Press `Win`, type **"For developers"**, open it, toggle **Developer Mode → On**.
- Then:
```bash
flutter run -d windows
```

**Mac:** run on the iOS simulator:
```bash
open -a Simulator
flutter run
```

**Any OS — Android emulator:**
- Open Android Studio → "More Actions" → "Virtual Device Manager" → create & start a phone.
- Then: `flutter run`

The first build takes a few minutes. When it's done, the app opens. To **sign in**, use the **"continue with email"** option (enter your email → you'll get a code → type it in). GitHub/Google login needs extra setup, so use email for now.

> While the app runs, press `r` in the terminal to **hot reload** (see code changes instantly) or `R` to **hot restart**.

---

## 🌿 How to work without breaking each other's stuff

**Never code directly on `main`.** Always make a branch for your task:

```bash
git checkout main
git pull                                       # get everyone's latest work
git checkout -b your-name/what-youre-doing      # e.g. arjun/feed-polish
```

Do your work, then save & share it:

```bash
git add -A
git commit -m "Short description of what you did"
git push -u origin your-name/what-youre-doing
```

Then go to GitHub → you'll see a "Compare & pull request" button → open a **Pull Request** so others can review and merge it into `main`.

> 🔁 Before starting new work each day: `git checkout main` then `git pull` to stay in sync.

---

## 🗺️ Where things live (project map)

```
lib/
  app/         → theme (colors, fonts), navigation/router
  core/        → config, constants
  data/        → models, repositories (talk to Supabase), services
  features/    → each screen, grouped by feature:
    auth/        sign in
    onboarding/  GitHub skill import
    profile/     your profile + avatar
    swipe/       the swipe deck + match animation
    chat/        messaging
    feed/        community feed
    home/        the bottom-nav shell
  shared/      → reusable widgets
supabase/migrations/  → the database schema (SQL)
docs/auth-setup.md    → how OAuth login providers are configured
```

**The backend** is **Supabase** (cloud — database, auth, file storage, realtime). Ask the team lead to invite you to the Supabase project so you can see the data and run database changes.

---

## 🆘 Troubleshooting

**"flutter: command not found"** → Flutter isn't on your PATH. Re-do the Flutter install step and restart your terminal (and VS Code).

**App shows a white screen / won't load** → make sure your `.env` file exists and has the correct keys (Step 3).

**"Target of URI doesn't exist" / red squiggles everywhere** → run `flutter pub get`.

**It signed me out after restarting** → known quirk on desktop dev builds; just sign in again with email. (Doesn't happen on real phones.)

**Build fails after pulling new code** → run `flutter pub get`, then try again.

**Still stuck?** Drop the exact error message in the team chat — copy the whole red text.

---

Made for the RedRob hackathon. Let's build. 🚀
