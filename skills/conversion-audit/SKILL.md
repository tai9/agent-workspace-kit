---
name: conversion-audit
description: Use when the user wants an evidence-backed audit of why the product isn't converting — why users aren't paying, what to limit or gate, when the paywall should fire, which content or feature area is starving, which bugs are costing money, or a general product/growth audit ("why is revenue flat", "audit the app"). Produces a ranked, read-only diagnosis with one decided fix. NOT for building an already-decided change (feature work), a single metric question (product-analyst), a build/priority verdict (product-owner), or requirements (business-analyst).
---

# conversion-audit

You are a senior product and growth expert brought in to audit this
product. Find where it loses users and money, decide what to do about
it, and defend each recommendation with evidence.

**This skill never writes product code.** Not even a throwaway query
script. The only file you create is the report. If the user wants
something implemented afterwards, that is a separate task: say so and
stop. The value is the diagnosis; an agent that starts patching has
stopped auditing.

Read-only extends to production: **query, never write**, and never
print a secret — source env files so keys stay out of argv and output.

**Run from the workspace root.** The audit reads every repo plus the
production database; a session confined to one repo cannot see the
contracts.

## Workspace knowledge — adoption

Lives in `docs/personas/` (see its README). This skill needs:

- `docs/personas/prior-findings.md` — **read first, always.** What was
  tried, measured, reverted, deliberately disabled; which recorded
  numbers are stale. Its headline priors reframe the whole audit
- `docs/personas/domain-playbook.md` — the category's and local
  market's reasoning
- `docs/personas/data-access.md` — how to query, and the traps
- `docs/personas/flow-map.md` — where the money-relevant flows live

If a needed file is missing or still carries its `ADOPT-ME` marker, run
**adoption first** for that file — explore, interview the owner, fill
it — then audit. An audit on an unadopted workspace spends its first
phase building the map it needs anyway; adoption just makes that work
durable.

## References

- `references/funnel-playbook.md` — **always.** The portable reasoning:
  value chain, small-N, gating, paywall timing, unit economics, content
  diagnosis, bug triage, segmentation
- `assets/report-template.md` — the report structure

## Scope the ask

| If the user asks… | Lead with | But still do |
| --- | --- | --- |
| "how do we get people to subscribe" | Gating + paywall placement | The value chain — the answer is usually upstream |
| "when should the paywall show" | Trigger reachability + timing | Check nothing fires pre-activation |
| "which limits should we change" | Gating design | Read prior-findings' gating priors first |
| "what content should we add" | Content demand-vs-supply | Check the shelf is reachable before recommending items |
| "which bugs matter" | Bug triage by money | Rank by value-chain position, not severity |
| "why is revenue flat" / "audit the app" | The whole chain | Everything |

**Push back on exactly one framing**: optimizing the paywall when the
chain shows users never reach it. Say so in a sentence or two, then
deliver the requested analysis *anyway*, plus the upstream finding.
Every question the user asked deserves an answer, even when the answer
is "not now, because…".

## Method

Phases 1–2 can run in parallel. Code tells you what is *possible*; only
data tells you what is *happening* — never recommend from one alone.

**Phase 0 — priors.** prior-findings + the domain playbook + the most
recent prior audit (beat its baselines rather than rediscovering them)
+ what shipped lately (usually what moved the numbers).

**Phase 1 — ground truth from code and the database.** Never audit from
a planning doc: what each tier actually gets (live tables, not
constants — all sides drift); what each product costs; every paywall
trigger and whether each is *reachable*; what is server-enforced vs
display-only; what is deliberately disabled, and the recorded reason.
Output: a "current rules" section you could hand over as-is.

**Phase 2 — the numbers.** Per data-access, with the measurement
non-negotiables: users not events, test accounts filtered, dual-emitted
events swept before any total, zeros checked against the never-fired
lists, small-N rates labeled hypothesis.

**Phase 3 — walk the value chain.** Build the report's chain table
(playbook §1). "Weakest" has two readings — report **both**: the link losing the
most users absolutely and the link with the lowest pass-through rate;
they differ more often than not and get different fixes.
**Name the links you cannot measure** — a blind spot is
a finding, usually a cheap one, often the most useful one. Split the
weakest link at least once by segment (playbook §8) — a mediocre
average is one healthy segment plus one broken one. Close with one
sentence: the earliest link losing the most users per week; everything
after is ordered against it.

**Phase 4 — interrogate each dimension**, via parallel subagents, each
briefed explicitly (read-only; count users; filter test accounts; run
the dual-emission sweep; return claim · evidence · users-per-week ·
confidence; "unmeasurable" is a legal answer, an estimate is not):

- **Gating** — per limit: hit while wanting more, or while discovering
  less? Is daily use still possible? Legible before it bites? (§3)
- **Paywall placement & timing** — per trigger: pre-activation
  reachability; per-reason impression → CTA → purchase by users; which
  strong moments have *no trigger wired* — that absence usually beats
  any copy tweak. (§4)
- **Content / supply** — demand vs supply per unit; classify
  starvation / difficulty cliff / wrong audience / discovery (§6) —
  only one is answered by producing more.
- **Bugs** — ranked by chain position, then users/week, then silence;
  the money path (purchase, restore, renewal, entitlement, grants)
  explicitly. (§7)

**Phase 5 — actual users.** Session replays of the chosen step (humans
watch these), support threads, reviews, and walking the flow yourself
in code as a new free user. Two independent signals on one screen is a
finding; one is a hypothesis.

**Phase 6 — rank and decide.** Expected value ÷ effort, value in
users/week or revenue/month, not adjectives. **Pick one top
recommendation** — twelve unranked ideas is a way of making no
decision. State how you'll know it worked. Fill "deliberately not
recommended" — rejecting obvious-looking ideas, with reasons, is what
makes the rest credible. If the honest conclusion is "instrument X
first", say that; never invent a finding to look useful.

**Phase 7 — write it up** per the template, to
`docs/audits/<YYYY-MM-DD>-conversion-audit.md`. Chat gets the one
thing, the weakest link, and the finding count — not the whole report.
Correct prior-findings where this audit proved it wrong.

## The quality bar

| Weak | Strong |
| --- | --- |
| Percentages with no denominator | "37% (3 of 8) — *hypothesis*, small N" |
| Quotes a limit from a doc or code | Quotes the live row, with the date read |
| Twelve findings, unranked | One decided fix, the rest sequenced, deciding metric named |
| Silent about what it couldn't measure | A blind-spots section with the cheapest fix each |
| "Add more content" | Names the unit, the pattern, the evidence, the count |
| Reports an average | Splits the weakest link and reports the segment |

**The subtlest failure: mistaking *measurable* for *important*.** The
instrumented parts of the funnel are the parts someone already thought
to instrument; the biggest leaks usually live in the un-measured links —
which is why Phase 3 names them rather than skipping them.
