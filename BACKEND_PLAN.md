# Sandbagger — Backend Plan (Supabase)

App: **Sandbagger** (the GitHub repo/URL is still `golf-games`). Single `index.html` (vanilla HTML/CSS/JS),
hosted at https://graham123hi.github.io/golf-games — repo github.com/graham123hi/golf-games.
Today everything saves to `localStorage` only.

Goal: add a real backend with **Supabase** (free Postgres + auth + realtime) so users get real
accounts (email/password + Google), data syncs across devices, friends are real, and a group can
play one **live shared scorecard** that updates on everyone's phone in real time.

Key fact: Supabase is **called from the browser** using a public "anon" key, protected by Row
Level Security (RLS). So we **stay on GitHub Pages** — no separate server, no leaving our host.
(A serverless host like Vercel is only needed later for the AI assistant's *secret* Claude key.)

## Progress / Status
- [ ] **C0 — Supabase project setup** (in progress)
- [ ] **C1 — Real accounts** (email + password + username + Google)
- [ ] C2 — Cloud data + real friends (later)
- [ ] C3 — Live shared games (later)

---

## Architecture
- Keep the existing vanilla-JS app and code style. No React rewrite.
- Add `@supabase/supabase-js` via CDN `<script>`; create one client (named `sb`) with the
  Project URL + anon key.
- All backend calls grouped together so app logic stays separate from network logic.
- Replace the `golfAccounts` localStorage layer with Supabase. Keep `localStorage` only as an
  offline cache where useful (the app is a PWA used on the course).
- Security: rely on **RLS** so each user only reads/writes their own data; shared rounds are
  readable by participants. The anon key in the frontend is expected and safe. The
  `service_role` key is secret and **never** goes in the app.

## Database schema (Postgres)
Created per phase so we only add what we need.

**C1 — `profiles`** (one row per user, linked to `auth.users`)
- `id uuid` (= auth user id, PK), `username text unique`, `name text`, `email text`,
  `photo_url text`, `chips int default 1000`, `wins int default 0`, `rounds int default 0`,
  `course text`, `ghin_number text`, `venmo/cashapp/zelle text`, `hc_rounds jsonb`,
  `friend_code text unique` (the `GF-XXXXXX` id), `created_at timestamptz`.
- A signup trigger auto-creates this row.

**C2** — `friendships`, `rounds`, `custom_games` (added later)

**C3** — `live_rounds`, `round_players`, `hole_scores` (added later; realtime enabled)

---

## Phase C0 — Supabase project setup
- Create the Supabase project (your clicks).
- Run the C1 SQL script (profiles table + RLS + signup trigger).
- Enable Email auth; optionally enable Google auth.
- Send the dev: **Project URL** + **anon key** (safe to share). Never the service_role key.

## Phase C1 — Real authentication
- Add supabase-js `<script>` + client init to `index.html`.
- Rewrite `doSignUp` / `doSignIn` / `doLogout` / `finishAuth` (`index.html` ~989–1032) to use
  `sb.auth.signUp`, `signInWithPassword`, `signInWithOAuth({provider:'google'})`, `signOut`,
  and `onAuthStateChange`.
- Sign-up form collects email + password + username + name; trigger creates the `profiles` row.
- Add a "Sign in with Google" button.
- Load the logged-in user's `profiles` row into the existing `profile`/`accounts` variables so
  the rest of the UI keeps working unchanged.
- **Milestone:** sign up on a phone, log in on a laptop, see the same account. We no longer store
  passwords ourselves.

## Phase C2 — Cloud data + real friends (LATER)
- Save/load `rounds`, profile edits, chips/wins, custom games, favorites to Supabase.
- Replace `MOCK_FRIENDS` + in-memory `friendsAdded` with the `friendships` table (search by
  username / friend code / GHIN; send + accept requests; real head-to-head).

## Phase C3 — Live shared games (LATER)
- Host creates a `live_rounds` row + short join code; friends join (`round_players`).
- Each stroke writes to `hole_scores`; a realtime subscription pushes changes to all phones.
- Reuse existing scoring math (`calcSkins`, `calcStableford`, `endRound`); swap data source from
  local arrays to `hole_scores`. Finishing writes results into `rounds` for all participants.

---

## Security checklist (PRD section 7)
- anon key in frontend = expected/safe; **never** put the `service_role` key in the app.
- RLS ON for every table.
- Supabase hashes passwords — we never store them (rule #60).
- Turn on 2FA for the Supabase account.

## Verification
- **C0:** client connects; a test query against `profiles` works under RLS.
- **C1:** create an account on phone, log in on laptop → same profile; Google button signs in and
  lands back in the app.
- Each phase: test locally (`python3 -m http.server 8000`), then push to GitHub Pages and re-test
  on a real phone (auto-rebuilds on push).
