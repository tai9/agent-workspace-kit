# Analysis playbooks

One section per job. Every job starts by reading `measurement-rules.md`
and checking `docs/personas/prior-findings.md`. Every job that will
**quote a total from production** (1, 2, 3, 5, 6, 7, 8, 9, 10, 11) also
runs the dual-emission sweep for its window first; jobs 4 and 12 design
against data rather than pulling it.

Sources of truth that live behind a local server or login (admin pages):
if unavailable, use the underlying query **and say so** — a silent
fallback is how hand numbers drift from what the team sees.

## 1. Metric Q&A

Proportion: a quick question gets a quick, *correct* answer, not a study.
Find the metric in metrics-catalog and use its source of truth (no entry
⇒ define inline and add it). Prefer, in order: an existing page/dashboard
→ a committed query/RPC → a hand query. Answer with the context block;
"unmeasurable because X" is an answer — never estimate into the gap.

## 2. Metric investigation ("why did this move")

Rules §6 in order — the whole job is that section:

1. **Reproduce the number** — same query, window, filters as whoever
   noticed it. Half of anomalies die here (partial period, unfiltered
   test account, dual emission, window edge).
2. **Instrumentation before behaviour** — dead events, renames, the
   sweep, crash reports that kill emission.
3. **Caps, gates, errors** — what did affected users' sessions end with?
4. **Composition** — new vs returning, platform, segment mix.
5. **Timeline overlay** — releases, patches, pricing, incidents.
6. Conclude: cause (survived all checks) or ranked hypotheses. Doc:
   the movement, what was ruled out with evidence, conclusion, what
   instrumentation would settle the rest.

## 3. Post-ship feature readout

1. Recover what was promised: the kill criteria and success metric from
   `product-owner`'s verdict. **No recorded criteria is itself the first
   finding** — say so, then propose the metric it should have had.
2. Window: ship date → now, minimum 14 days for a habit claim; if the
   product ships staged/OTA, gate the window on rollout adoption, not
   the cut date.
3. Three layers, per user: **reach** (saw/opened, % of actives),
   **depth** (core action completed, repeat rate), **impact** (the
   metric it was built to move — under §6 discipline, usually
   "hypothesis" at small N).
4. Compare against the criteria verbatim: met / not met / not
   measurable, and why.
5. Doc + chat: the criteria verdict, the three layers in a line each,
   and the handoff — keep/iterate/kill is `product-owner`'s call.

## 4. Metric spec for a new feature

A doc the implementing engineer wires without questions and
`product-owner` lifts into its measured-by slot:

1. The feature's hypothesis as a measurable sentence.
2. Success metric + threshold + window, and the guardrail that must not
   degrade.
3. Events: names (check the shared namespace for collisions and follow
   its conventions), properties with types, **who emits**
   (server-authoritative wherever state changes server-side; if both
   sides must emit, mandate a source tag from day one), and the funnel
   they must reconstruct.
4. Reuse before invent: an existing event plus one property beats a new
   event; check the live inventory.
5. Dry-run the job-3 readout on paper against the spec — provably
   sufficient or not yet done.
6. Doc; implementation is feature work — hand off, don't wire.

## 5. Funnel analysis

State the scope first: **per-user or per-session**, and whether steps
may span days — the most common funnel-definition bug. Steps from
events that **exist and fire** (inventory first — a funnel with a
never-fired step is a job-9 finding). Per-user windowed funnels, never
event-counting ones; state the window constant. Absolute users at every
step alongside rates, and name **both diagnosis targets**: the biggest
leakage step (largest absolute users lost) and the weakest step (lowest
step-to-step rate) — usually different steps, with different fixes.
Drill into the worst step mechanically: compare the **segment
composition** (platform, tier, entry path) of users who entered it
against users who passed it before writing any hypothesis.

## 6. Retention & cohorts

Committed cohort queries first. Define day-bucketing explicitly.
Cross-system cohorts: define in one system, carry the user-id list to
the other. Feature-touched cohorts are self-selected — "correlated,
self-selected", never the feature's effect. Show cohort sizes in every
row; tag small ones. **Read curves, never points**: compare the
retention curve across cohorts — sharp early drop with a low plateau =
onboarding/first-value mismatch; a plateau that erodes = a habit or
depth problem; newer cohorts above older = recent fixes working. And
**never blend free and paid users in one retention number** — they
churn for different reasons at different rates.

## 7. Segmentation

Cut by the axes metrics-catalog lists. Any average worth reporting is
worth splitting once — a mediocre average is frequently one healthy
segment plus one broken one. Segments below ~10 users: report the count
and stop. Output: a small table, absolute counts in every cell, one
sentence on the split that mattered.

## 8. Revenue & subscription reporting

The ledger and its committed views first (rules §7); split every total
by source and paid/trial/promo; prices from the live price table. Churn
and renewal from per-user ledger sequences — distinguish voluntary
cancellation from billing failure from sandbox. This job **reports**: a
mechanical/mix cause behind a movement is job 2; "why aren't they
paying" routes to `conversion-audit` by name.

## 9. Data-quality audit

**Quick check — one event**: live inventory filtered to it, its
silent/undocumented flag where the workspace tracks one, the never-fired
list. Three lines in chat; upgrade to the full audit if something
systemic appears.

**Full audit** (trust wobbles, or quarterly): ranked live inventory vs
expectations; dead instrumentation; the dual-emission sweep for drift;
never-fired/does-not-exist lists refreshed against prior-findings;
null-rate spot-checks on load-bearing properties; identity health
(un-identified events after login). Doc: broken / silent / drifted /
fine with evidence and the cheapest fix each; fixing is feature work;
prior-findings gets corrected where proved stale.

## 10. Opportunity sizing

Define the touched population precisely (surface, segment, flow
position); query its size over the default window; express as users/week
and % of actives. Layer conversion assumptions only if asked, each
tagged **assumed** with an analogous measured rate cited. One line of
framing, then hand to `product-owner`.

## 11. Review ritual

If the workspace has a written analytics-review ritual, run it, don't
reinvent it. If none exists, propose one as the engagement's deliverable:
a short daily read (what moved that shouldn't have) and a weekly one
(adoption → biggest drop by absolute users → qualitative check → **one
decided fix**), then record it where the workspace keeps such docs.

## 12. Dashboard curation

Reuse existing insights before creating new ones. House conventions:
every tile filters test accounts, and every tile carries a description
saying what it means *and how it lies* — a tile without its caveat is
unfinished. Definitions come from metrics-catalog; a new definition
created for a dashboard lands in the catalog in the same change. A
standing metric earns its tile only with a **decision rule** — threshold
plus "if below X for <window>, then Y" — in the tile description; a
number nobody would act on is decoration. (The same rule binds job 4's
success metric.) A one-off question is a query, not a dashboard.
