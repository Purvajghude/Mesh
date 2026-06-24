# Mesh — Credit / Time-Bank Economy (Design)

**Status:** Design only · 2026-06-23 · from a 3-lens council brainstorm (mechanism design + growth + trust&safety). **Not implemented.** All numbers are v0 defaults — tunable.

---

## 1. Principles (the non-negotiables)

1. **Conserved, not minted.** A help session is a zero-sum transfer (requester −N, helper +N). Helping does **not** print new money. The only faucet is a gated onboarding grant; the only sink is demurrage. This is what makes credits a *currency* and kills reciprocal-farming at the root.
2. **Two ledgers, crisp split.** XP = **stock** (permanent, earned competence, never transferable). Credits = **flow** (circulating, what you owe / are owed). One line for users: *"XP is who you are. Credits are what you owe and are owed."*
3. **XP prices credits. Credits never buy XP.** Competence sets the rate band; the currency can never touch the competence signal (protects the RedRob data product).
4. **Don't meter the clock.** Price per *request*, agreed up front, settled by escrow. "Time" is a human size-hint, not an audited quantity.
5. **Liquidity before economy.** Credits stay dormant until a campus is match-liquid. The economy is the retention/scorekeeping layer, never the growth engine.

---

## 2. The unit & pricing

**Credit** = the base unit, intuitively ≈ 30 min of focused help (so an hour of help ≈ a couple of credits). But you never log minutes — you pick a **size** and the **helper's proven level** sets the rate.

**Request size (base credits):**

| Size | Rough effort | Base |
|---|---|---|
| Quick | ~30 min (a review, a debug nudge) | 1 |
| Standard | ~1–2 h | 3 |
| Deep | ~half-day | 6 |

**Helper XP multiplier** (their earned level in the requested skill):

| Level | Multiplier |
|---|---|
| L1–L2 | ×1.0 |
| L3 | ×1.25 |
| L4 | ×1.5 |
| L5 | ×2.0 |

**Suggested price = round(size_base × multiplier).** Helper may nudge **±1**. **Hard cap 12 credits/request** (no whales).

> Why: flat "1 hr = 1 credit" punishes experts (they stop showing up — the classic time-bank supply collapse). Anchoring price to *demonstrated* competence is defensible, needs no haggling, and keeps high-value skills in the market. A beginner's hour genuinely costs less because their proven level is lower — and they can still earn at what they're good at.

---

## 3. Money supply (the only faucet + the only sink)

- **Onboarding grant: 5 credits**, one-time, **identity-gated** (unlocked only after the user verifies a campus email *and* connects ≥1 platform / passes one portfolio judge — reuse the handle-ownership rail from migration 0016). Enough to *receive* help before earning. This is the sole way new money enters.
- **Demurrage (gentle decay): 2%/week on the balance above 15.** Never decays below 15 (your "working capital" is safe) and never touches XP. Keeps credits circulating instead of hoarded; framed in-product as *"credits are for spending, not banking."*
- **Conservation invariant** (auditable): `total_supply = Σ grants − Σ demurrage`. Transfers net to zero. If this identity ever breaks, there's a minting bug.

**Free help** earns **XP + non-transferable karma + a pay-it-forward edge** — never spendable credits. (Karma drives ranking and the impact leaderboard only.)

---

## 4. Request lifecycle & escrow

```
open → accepted(escrow held) → delivered → confirmed         → settled (helper paid)
                                          ↘ (72h silence)     → auto-released (helper paid)
                                          ↘ disputed(frozen)  → review → settle/refund
```

- **Escrow on accept:** the moment a helper accepts, N credits move requester→escrow (held, spendable by neither). You can't offer credits you don't have.
- **Release on confirm:** requester confirms → escrow → helper. A completed paid session **also logs XP** for the helper in that skill (one action, both ledgers).
- **Auto-release after 72h** of no confirm/dispute → helper paid. Kills the "do the work, then get ghosted" hostage problem; silence resolves in the helper's favor.
- **Dispute** → freeze escrow → light review (a small admin/AI queue is fine at hackathon scale). No unilateral clawback after release.

**Soft overdraft:** trusted users (reputation ≥ threshold *and* ≥3 completed sessions) may float to **−3**; new users hard floor at 0. Avoids the harshest cold-start lock.

---

## 5. Urgency = a paid premium (not a free flag)

A free "urgent" checkbox → everyone ticks it. Instead: **urgent adds +50% into escrow** (requester pays it) and surfaces higher in helpers' queues. It self-rations because it costs something — clean mechanism design, zero moderation.

---

## 6. Ratings & trust

- A rating exists **only after a confirmed, released transaction** (no rating without a real transfer → kills drive-by rating bombs).
- Dimensions: communication, helpfulness, expertise, reliability. One rating per transaction per direction; immutable after a short edit window.
- **Cold-start:** new users show "new", not a fake 5.0. Ratings are **weighted by the rater's own trust**, so a ring of fresh accounts can't manufacture reputation.
- **Reputation** (derived, never buyable) = f(confirmed sessions, trust-weighted ratings, confirm-rate). Gates overdraft + urgent access + feeds the swipe ranking (reliable helpers surface more).

---

## 7. Anti-abuse (build on what's already shipped)

| Vector | Defense | When |
|---|---|---|
| **Credit minting via fake/free help** (the #1 risk) | Conserved ledger + free help mints only karma + gated faucet | must-have |
| Offering credits you don't have / ghosting | Escrow on accept + auto-release | must-have |
| Double-confirm / replay | Idempotent confirm, unique per request (like the collab-XP dedup) | must-have |
| Wash-trading / credit laundering | Velocity caps (below) + new-pair friction + later: cycle-detection on the graph | caps now, detection later |
| Off-platform credit-for-cash sale | Credits non-withdrawable, non-transferable except via a reviewable request, + demurrage discourages stockpiling | structural |
| Rating collusion | Down-weight reciprocal-only rating pairs; trust-weighted | later |
| Campus-email Sybil | Domain allowlist (reject disposable/free providers), one account/email, signup rate-limit per domain, caps tied to *identity strength* not just email | must-have |

**Velocity caps (per identity, v0):** ≤15 credits earned/day · ≤8 credits between the same pair/week · ≤3 concurrent open requests · ≤20 total escrowed. **New-pair friction:** first 3 transactions between accounts with no other graph links get half-caps + 7-day auto-release.

**Cycle-discounted impact metric:** the community-impact / pay-it-forward leaderboard must be PageRank-style with damping (or strip mutual edges) so circular help can't inflate it. Naive sum-of-help is trivially gamed.

---

## 8. Schema sketch (design — not built)

Reuse the patterns already shipped: append-only ledger (like `skill_events`), RLS owner-read / backend-write only, per-tuple dedup, service-role writes.

- **`credit_ledger`** (append-only, double-entry): `id, from_profile (null=faucet), to_profile (null=demurrage sink), amount, type(grant|transfer|escrow_hold|escrow_release|demurrage|refund), request_id, created_at`. Balance = `Σ to − Σ from`. Cache on `profiles.credits` (derived is source of truth).
- **`help_requests`**: `id, requester_id, skill_id, title, description, size(quick|standard|deep), credits, urgency(normal|urgent), status, helper_id, created_at, accepted_at, deadline`.
- **`collab_ratings`**: `id, request_id, rater_id, ratee_id, communication, helpfulness, expertise, reliability, created_at`, `unique(request_id, rater_id)`.
- **Reputation/karma**: derived view (or cached on profile) from ratings + confirm-rate; karma from a free-help log. Never client-writable.
- All credit movement happens **only** through backend (service-role) functions inside DB transactions that enforce the non-negative / overdraft constraint server-side.

---

## 9. GTM — the hyperlocal hackathon wedge

**The atomic network is not a campus — it's one hackathon / club.** Win one fully, then bleed outward.

**Highest-leverage move:** launch Mesh as the **official team-formation tool for one hackathon on a campus where a team member is physically present.** A hackathon is a cold-start machine with a built-in deadline — it collapses all three cold-starts (match market, economy, hyperlocal) at once.

**Rollout:**
1. **T-minus 1 week — seed supply.** Hand-onboard 15–20 "anchor" builders (the known-strong club members); backfill their XP from GitHub so the deck opens to real, impressive people. An empty deck on day one is death.
2. **T-0 — the event.** Onboard 50–200 in an afternoon. The only loop that matters: *onboard → connect GitHub (instant XP + credibility) → swipe → match → AI pitch → start building.* **Credits stay dormant here** (liquidity first).
3. **During — switch the economy on** once request volume crosses a threshold. Everyone's 5-credit grant makes the first spend frictionless. The **urgent-request feed becomes the home screen** ("need a designer in 2h, 3 credits") — this is the real retention engine, not the swipe deck.
4. **Post-event — virality.** A shareable team artifact ("we built X; here's our complementarity graph + the pitch Mesh generated") posted in the event Discord/LinkedIn is the cross-campus vector. **Founding-Builder badge** for the first 50 verified accounts per campus turns cold-start into a status race.
5. **Expansion.** Inter-college hackathons (common in the tier-2/3 circuit) bridge campus→campus; surface complementary teammates from rival campuses.

**Best viral mechanic:** **ghost-profile "match-pull" invites** — swiping someone not yet on Mesh sends an invite carrying a *specific named demand* ("you wanted to team with X — invite them to unlock the match").

**Retention hooks (priority order):** urgent-request feed → XP that levels on *completing help* (not one-time account connects) → help-streaks (contribution, not logins) → credit balance framed as a *repayable obligation/deficit*, not idle savings.

**Biggest growth risk:** shipping the economy before liquidity → time-bank death spiral. Mitigation: credits dormant until a request-volume threshold; seed everyone; design for deficit (drives activity) not savings (sits idle).

---

## 10. Why this is a RedRob multiplier

Swipes = *stated* preference ("I think I'd work with them"). The credit economy = **revealed, outcome-labeled** data: `request → accept → deliver → rate → credit-flow` is a validated record of *"this skill pairing was asked for, delivered, and rated."* Plus:
- **Credit flow = a live value graph** — who the community actually relies on, which skills are in real demand (priced, with urgency).
- **Open-bounty board = a real-time skills-shortage heatmap** per campus.
- **Pay-it-forward / reciprocity structure** = network-position data (hubs, connectors, reliable closers) — exactly the "who makes teams work" intelligence enterprise HR can't get from résumés.

Frame: *"We're not building a résumé database; we're building a labeled dataset of human collaboration outcomes — and a campus is the cheapest place on earth to generate it."*

---

## 11. Phased build order (when it's time)

1. **Foundations:** `credit_ledger` + balance derivation + onboarding grant (gated) + wallet UI. Credits *visible but quiet*.
2. **Requests + escrow:** help-requests, accept→escrow→confirm→auto-release, urgency premium.
3. **Trust:** ratings (post-settlement only), reputation, overdraft/urgent gating, reputation→ranking feedback.
4. **Liquidity & hygiene:** demurrage, velocity caps, new-pair friction, open-bounty board.
5. **Later:** graph cycle-detection, impact leaderboard (cycle-discounted), mentorship credits.

---

## 12. Open questions (decide before building)

- Credit:time anchor — keep "≈30 min = 1 credit" as the mental model, or drop time language entirely?
- Onboarding grant size (5?) and demurrage rate (2%/wk above 15?) — calibrate against expected campus size.
- Does free help also need a *small* cap on karma to avoid leaderboard farming, or is non-transferability enough?
- Mentorship credits: do senior→junior sessions get a platform subsidy (a sanctioned mint), or stay conserved? (A subsidy is the one place a controlled mint might be worth it for social impact — needs a cap.)
