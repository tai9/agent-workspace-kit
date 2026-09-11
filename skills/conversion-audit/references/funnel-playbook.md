# Funnel playbook

The portable reasoning for a consumer subscription product. The
category- and market-specific halves (benchmarks, local willingness to
pay, what converts in this product's category) live in
`docs/personas/domain-playbook.md` — read both; where they disagree,
the domain playbook wins, because it was written closer to the ground.

## 1. The value chain, in order

Diagnose in sequence; a weak late link is often a starved early one:

```
install → account → activation (first real value delivered)
→ habit (returns without being pushed) → limit felt
→ paywall seen with a reason → purchase → renewal
```

Rules that follow from the ordering:

- **Fixing a link only helps users who reach it.** Paywall polish is
  worthless to users who never activated. The audit's job is finding
  the *earliest* link losing the most users per week.
- **Activation is delivering the product's core value once**, not
  completing signup. Define it honestly; proxies (a session opened, a
  screen viewed) get named as proxies.
- **Habit precedes monetization.** A user who hasn't returned unprompted
  has nothing to lose by hitting a wall — a limit felt *before* habit
  converts nobody and churns somebody.
- **Renewal is part of the chain.** A conversion audit that stops at
  first purchase misses the cheapest revenue there is.

## 2. Small-N discipline

At small scale (hundreds of actives, single-digit payers):

- Rates under ~30 users in the denominator are hypotheses; say the
  absolute counts.
- One user's week moves weekly lines double-digit percent — movements
  inside that band are noise without a mechanism.
- Structural evidence (a trigger that *cannot* fire, a link with *no*
  instrumentation, a price shown wrong) outranks statistics and is
  decidable at any N — prefer it.
- Cohorts and natural experiments (a promo expiry, a forced update)
  beat A/B tests you don't have the volume to run.

## 3. Feature gating — what actually converts

Per limit, the questions that matter:

- Does a free user hit it **while wanting more** (mid-flow, engaged) or
  **while discovering they have less** (before value, insulted)? The
  first converts; the second churns.
- **Is daily use still possible?** Habit formation needs a daily free
  loop; a gate that blocks the habit kills the funnel that feeds the
  paywall.
- **Is the limit legible before it bites?** A meter that counts down
  converts; a surprise wall enrages.
- **Reach before scarcity:** tightening a gate only helps if users
  *reach* it. If few free users ever hit the current limit, the
  problem is upstream engagement, not gate generosity — check
  prior-findings; this exact proposal has usually been examined.
- What is server-enforced vs display-only? A limit only the UI knows
  about is a suggestion.
- **Value sampling beats hard gating**: before recommending a tighter
  limit, name the alternative — intersperse tastes of paid value into
  the free flow (the Grammarly pattern) so users learn what they'd pay
  for by using it, not from a lock screen. And keep the model straight:
  **free is an acquisition strategy, not a monetization strategy** —
  the free tier is judged by the activated users it feeds the paywall.

## 4. Paywall timing

- Map every trigger: reason, surface, and whether it can fire
  **pre-activation** (any that can is a bug — it monetizes users who
  haven't seen value).
- Strong moments: quota exhausted mid-flow, a scored result worth
  keeping, a streak or progress about to be lost, day-2/3 of an
  evident habit. Weak: app open, onboarding end, random interstitials.
- **The strong moment with no trigger wired at all** usually beats any
  existing trigger's copy as a finding.
- Every surface emits both a shown and a dismissed event, or its
  conversion rate is fiction.
- Per-reason funnel (impression → CTA → purchase), by users; a reason
  with impressions and zero purchases is mis-timed, mis-priced, or
  mis-audienced — the split says which.

## 5. Unit economics

For products whose usage has real marginal cost (AI inference, voice,
media):

- Know the cost of one active free user per month, and which feature
  drives it; watch the p95, not the mean — one runaway session is how
  regressions surface.
- The free tier is a COGS decision wearing a growth costume. "More
  generous free" proposals get priced per-user before they get judged.
- Anything that *grants* the expensive resource (referrals, streak
  rewards, promos) competes with its own paid SKU — check the grant
  ledger for how much is given away vs sold.
- Margin per paying user, at the real mix of plans, is the number every
  recommendation ultimately serves.

Three pricing-structure checks before touching a price point: does the
**value metric** scale with delivered value (the one pricing decision
that matters most); is the debate at the right **order of magnitude**
(never audit-argue small deltas while packaging is wrong); and is
"underpricing" actually a **packaging failure** — too few tiers for the
willingness-to-pay spread. Also compute the **churn ceiling**
(`≈ new users per period ÷ churn rate`): current churn implies a maximum
size no acquisition can beat, and if that ceiling is near, the audit's
headline belongs to retention, not the paywall.

## 6. Content and supply — gap vs mismatch

When a content-shaped surface underperforms, four diagnoses, only one
answered by producing more:

- **Starvation** — engaged users exhaust what exists (high completion,
  repeats, then drop). Answer: more of the same.
- **Difficulty cliff** — entry works, the next step loses them (scores
  collapse at a specific point). Answer: fill the gap, not the end.
- **Wrong audience band** — supply is aimed above or below the actual
  users (low starts despite traffic, or low scores from the first
  item). Answer: re-aim, not expand.
- **Discovery** — the content is fine and unreachable (low entry, high
  completion among those who enter). Answer: surface it; producing
  more makes the pile bigger, not more found.

Count supply from the live store, not the repo — what is authored and
what is published diverge.

## 7. Bug triage by money

Rank defects by **chain position × users/week × silence**, never by
crash volume:

1. Money-path defects first — purchase, **restore, renewal**,
   entitlement resolution, discount application, the grant ledger. A
   silent restore failure churns payers who wanted to stay.
2. Then activation-path defects — a broken first-run loses every user
   it touches at the top of the chain.
3. Silent failures outrank loud ones at equal position — loud bugs get
   reported; silent ones just subtract.
4. Expired-but-live surfaces (a blocker for a disabled feature, an
   orphaned route) are bugs even though nothing crashes.

## 8. Segment before you average

Split the weakest link at least once — by lifecycle stage, entry path,
platform, user level, tier history. A step that looks mediocre on
average is frequently fine for one segment and broken for another, and
only the split says which to fix. Averages are where findings go to
hide.

## 9. Reading qualitative signal

Replays, reviews, support threads, and walking the flow yourself:
highest information per minute at small N. Two independent signals on
one screen is a finding; one is a hypothesis. Replays show layout and
where a thumb went, never content — content questions need events or
transcripts, per the workspace's privacy rules.
