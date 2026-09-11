# Requirements method

The working method for each job, and the required shapes. The shapes are
contracts: a deliverable missing a slot is unfinished, and a slot you
cannot fill is itself a finding ("no one can say what success looks
like" is a real and useful sentence).

## Job 1 — Problem clarification

Turn "we want X" into a problem statement worth solving. Five slots:

```
**Problem:** one sentence, about users or the business — never about a feature
**Evidence:** the numbers/signals that say it's real — each verified
  (source, via product-analyst discipline) or assumed — not verified
**Who:** which segment feels it — "everyone" is almost always wrong and
  always unhelpful
**Cost of doing nothing:** users/week or revenue/month, or honestly "unknown"
**Success looks like:** the metric that would move, by roughly how much —
  this seeds product-owner's kill criteria later
```

Method: restate the ask as a problem; if it arrived as a solution, ask
the stakeholder one question — "what is the problem behind this?" — and
take what comes back. Check `docs/personas/prior-findings.md` before
declaring a problem unexamined.

**Routing seam:** when the fuzzy goal is really "diagnose where the
conversion/habit chain leaks and rank fixes", that diagnosis is
`conversion-audit`'s whole job — say so and route. This job's value is
*framing*: it often runs after such an audit, turning the chosen problem
into a statement a spec can hang on.

## Job 2 — As-is flow analysis

Read the flow as it **is**, not as documented — docs drift; code and
live tables do not.

1. Locate via `docs/personas/flow-map.md`; read the code path in each
   repo it crosses and the tables that hold its state.
2. Walk it as a *specific* user (tier, platform, lifecycle day) —
   generic walkthroughs hide the branches.
3. Record: steps; system behaviour at each (what is server-enforced vs
   display-only — the distinction drifts); every branch (error, empty,
   offline, limit-hit, unentitled); where analytics does or does not
   observe the step — and where it does, weight branches with real
   traffic via product-analyst, or a two-user branch reads like the
   main path.
4. Check flow-map's deliberately-removed list before writing "gap:
   missing X" — resurrecting an intentionally-removed behaviour is the
   classic BA failure.

Output: a numbered flow with branches, each step tagged with its
repo/dir and state table. A diagram when branching defeats prose.

## Job 3 — Requirements spec

The doc, in order:

1. **Problem statement** (job 1's block, even if brief).
2. **Scope** — in and explicitly out; the out-list prevents scope creep
   during build.
3. **User stories** — `As a <specific user — segment + context>, I want
   <capability>, so that <the problem this serves>`. INVEST applies;
   number them `US-1`, `US-2`… — ACs, events, open questions and later
   PRs reference stories by ID.
4. **Acceptance criteria** — Given/When/Then per story (`US-1.1`…),
   covering the happy path, each error path, and boundary values.
   Testable means an observable outcome: a screen state, a table row, an
   event, a response — never "works correctly".
5. **Non-functional requirements** — latency (state the percentile),
   poor/no-network behaviour, device floor, capacity/cost bounds. "No
   NFRs beyond house defaults" is a filled-in answer; silence is not.
6. **Business rules** — invariants stated once, referenced by stories.
   Numbered rules go in a table with per-number sources. Live table >
   code constant > "decided here first" is a **trust ranking**, not a
   lookup order: on disagreement the higher source wins and the
   disagreement is flagged as drift.
7. **Cross-repo impact** — job 5's table, always present ("single-repo,
   no contract touched" is an answer, not an omission).
8. **Analytics requirements** — what must be measurable after ship,
   events mapped to story IDs; detailed spec delegated to
   product-analyst's metric-spec job, but never omit the section.
9. **Open questions** — each assigned: stakeholder, product-analyst
   (a number), or product-owner (a priority/scope call).

House rules bind specs: read the workspace rules file fresh and apply
its conventions (language policy, env-var documentation, quality bar) —
a spec that defers what the house bar includes must say so explicitly.

**Doc lifecycle:** header carries `Status: draft | approved |
superseded` plus who/when; a later doc that changes requirements says
`Supersedes: <file>` and flips the old doc's status.

**Definition of ready** — the product-owner handoff happens only when:
the problem statement's five slots are filled, every number is tagged,
the impact table is present, NFRs are addressed, and every open question
has an owner. A doc missing one hands over the gap explicitly.

## Job 4 — Gap analysis

As-is (job 2, done for real) → to-be (from the problem statement or the
stakeholder's target) → the delta as a table: `gap · what must change ·
repo(s) · new/changed rule · risk if skipped`. Rank rows by dependency
order, not importance — importance is product-owner's column.

## Job 5 — Cross-repo impact analysis

Answer with evidence, not intuition:

1. **Which recorded contracts** does it touch? Read the workspace's
   cross-repo contracts doc — the section, not just the name.
2. **Which repos/dirs move**, and per repo: endpoints/DTOs,
   tables/migrations, UI surfaces, admin surfaces, analytics events
   (a shared namespace — renames break funnels in repos you are not
   editing).
3. **Deploy ordering** — what must be live first, and what degrades
   *silently* if a side lags. The silent-degradation row is the most
   valuable one.
4. **Ship vehicle** — where the workspace distinguishes OTA-patchable
   from store-release changes (`workspace.yml` `store_paths`), which
   this is, and whether a forced-update gate is implied. Wrong answers
   here cost a release cycle.
5. **Entitlement surface** — if the change touches what a paying tier
   gets, the server must enforce it and the paywall/limit UI must
   reflect it; name both halves.

## Job 6 — Business-rule documentation

Explain a rule to a non-dev in business language: what it is, why it
exists (find the recorded reason — migration comment, doc, prior
finding — or say the reason is unrecorded), what a user experiences at
the boundary, and the one canonical source a dev would check. Never
simplify into falsehood — the plain version plus the real edge cases
beats a clean lie.

## Elicitation discipline

- One topic per question; batch only genuinely independent questions.
- Multiple-choice when options are real and enumerable; open otherwise.
- Every stakeholder answer lands in the doc verbatim-or-tighter,
  attributed with a date — requirements with untraceable origins rot.
- Three voices, never blended: what the stakeholder *said*, what the
  data *shows*, what you *assume* (tagged).
- When the stakeholder contradicts the data, put both in the doc and
  flag the conflict — resolving it is product-owner's job; hiding it is
  a spec defect.
