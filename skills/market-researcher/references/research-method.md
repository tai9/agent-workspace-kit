# Research method

## Evidence tiers

Every load-bearing claim carries a tier and a date. Higher tier wins on
conflict; same-tier conflicts are reported, not averaged.

| Tier | Source | Trust |
| --- | --- | --- |
| A | First-hand this engagement: store listing read today, official pricing page, official blog/changelog, filings | Quote freely, with date |
| B | User-generated, recent, plural: store reviews (this product's market's store for market behaviour), forums, multiple independent recent walkthroughs | "Users report…"; two independent sources make a claim, one makes a hypothesis |
| C | Secondary: teardown blogs, growth case studies, talks | Hypotheses and vocabulary; verify against A/B before it bears weight |
| D | Memory, undated screenshots, "everyone knows" | Never load-bearing; write "unverified" |

Constraints to state, not hide: you cannot install or run the apps and
cannot watch videos — you read *about* products more than you observe
them. Browser tools, when available, may read **public** pages;
paywalled and logged-in states are off limits by rule, not just
ability — never create accounts or log in on the product's behalf. A
question that truly needs hands-on observation is job 6.

**Search discipline:** prefer the last 12 months and say when the best
evidence is older. Store listings, official pricing pages and help
centers are the highest-yield fetches. Version-check: a mechanic from an
old teardown may be gone — find a recent confirmation before quoting it
as current.

## Job 1 — Single-app teardown

Nine dimensions; "not researched" is a legal cell, silence is not.
Depth follows the ask — a focused teardown does its 2–3 dimensions
deeply and the rest at a paragraph.

1. **Positioning & audience** — who it's for, the promise, how it
   differs from its own competitors.
2. **Onboarding** — steps to first value, what it asks before showing
   value, level/segmentation handling, permission asks.
3. **Core loop** — the daily unit of work, session length, what brings
   users back tomorrow.
4. **Core-value delivery** — how the product actually does the job it
   sells (for a learning product, the pedagogy and what it measures as
   progress), and whether that plausibly works for the claimed outcome.
   Mandatory at depth in every teardown — it is the dimension teardown
   blogs skip.
5. **AI usage** — where AI sits, what's real vs marketing,
   latency/quality signals from reviews.
6. **Retention mechanics** — streaks, social pressure, notifications;
   which mechanic carries the load and what reviews say it feels like.
7. **Monetization & unit economics** — free-tier shape, gate placement
   and timing, trial design, prices (currency, region, date), discount
   patterns. For AI products add the COGS read: a "generous" free tier
   is a cost statement — estimate what their free usage plausibly costs
   them, against this product's own per-unit cost (from its cost
   tracking, via product-analyst — never guessed).
8. **Distribution & acquisition** — store positioning/ASO, visible paid
   channels, referral/virality mechanics, content presence. Check what
   the workspace already tracks here before re-deriving.
9. **This product's market** — localized? local pricing? local-store
   review sentiment? If irrelevant to the ask, one line saying so.

Close with **learnings, not summary**: 3–7 numbered observations this
product could act on, each with tier and a first-pass transferability
note. Doc: `docs/research/<date>-teardown-<app>.md`.

## Job 2 — Dimension benchmark

1. Fix the dimension precisely ("free-tier daily allowance and what
   hitting it looks like", not "monetization").
2. 3–6 apps: the closest analog, one category giant, one recent
   entrant — name why each is in the set (the landscape's roster
   seeds it).
3. **Fill this product's own row first, from code/DB or
   product-analyst** — it is the row the table exists for.
4. One table; one observation date per cell (or per row); free vs paid
   state explicit.
5. Read the spread: where this product is an outlier, is it deliberate
   (a recorded decision — check prior-findings) or accidental?

## Job 3 — Market scan

Time-boxed breadth: new entrants, notable launches/pivots/shutdowns,
platform shifts that change what's viable. Output: what changed, why
this product might care, each with a source — and an explicit "nothing
actionable this scan" when true. Feed durable facts into the landscape
file.

## Job 4 — Learning synthesis

The output product-owner consumes. Per proposal:

```
**Learning:** the mechanism observed, and where (tier + date)
**Why it works there:** the causal story in their context
**Transferability:** what must be true at this product's
  scale/audience/content supply for the mechanism to survive — known
  true, known false, or unverified
**Our version:** the smallest version worth considering here
**Measured by:** the metric that would show it working (seed for
  product-owner's kill criteria)
```

Rank by transferability-confidence × problem-fit, not by how impressive
the source app is. 3–5 proposals beat 12. Include a **"deliberately not
proposed"** list — the shiny mechanics you rejected and why. End with
the handoff: inputs for product-owner verdicts, per proposal.

## Job 5 — Pricing & packaging comparison

1. This product's row from its live price table, never memory.
2. Competitor prices from official pages/listings: currency, region
   (the local price where it exists — global apps price-discriminate),
   billing period, date. Convert at a stated rate; keep originals.
3. Compare *structure*, not just points: what the free tier teaches vs
   withholds, trial shape, monthly↔annual spread, top-ups/lifetime,
   student pricing.
4. Willingness-to-pay signals: local review complaints about price,
   local promo patterns.
5. No recommendation beyond observation — pricing *changes* are
   product-owner territory with conversion-audit's priors; say so.

## Job 6 — Primary-research design

For questions only a human with the app or a real user can answer. The
deliverable is a **one-page protocol** someone can execute in under an
hour:

```
**Question:** the one thing this study answers
**Method:** install-and-walk / N short user interviews / a screenshot
  checklist — the cheapest that answers it
**Steps:** numbered, ≤10, exactly what to capture at each (screenshot,
  quote, timestamp) — runnable with no research background
**Time:** honest estimate; over ~1 hour, split the study
**Bring back:** the artifact list and where it lands (docs/research/,
  the landscape file)
**Bias guard:** the one way this method most likely misleads (e.g. a
  fresh install shows an A/B arm you can't choose)
```

Interview protocols add: 3–5 open questions, no leading phrasing,
quotes land verbatim with speaker context. This job designs; running it
and interpreting artifacts is a follow-up engagement with tier-A/B
evidence.
