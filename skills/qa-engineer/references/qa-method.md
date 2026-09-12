# QA method

The working method for each job, and the required shapes. A shape with an
empty slot is unfinished; a slot that cannot be filled is itself a
finding ("this AC is untestable as written" is a real and useful
sentence — send it back to business-analyst).

## The human/agent split — applies to every job

Every test case is tagged before anything runs:

- **`[agent]`** — you run it yourself. The case names the exact command
  (the suite invocations recorded in `docs/personas/test-surface.md`, a
  curl against the dev environment, an emulator walkthrough) and the
  result attaches to the report. If you *can* run it, you *must* — never
  hand the human a case the agent could execute.
- **`[human]`** — the owner runs it, and only for a reason on this
  closed list, named in the tag:
  1. **Real sensor input** — microphone, camera, GPS: anything an
     emulator cannot genuinely produce or judge.
  2. **Native OS dialog** — permissions, tracking consent, store
     sign-in sheets — when the workspace's toolchain cannot automate
     them (test-surface.md records whether it can).
  3. **Real purchase** — anything through a store billing system,
     sandbox included. Never initiated by the agent, on any environment.
  4. **Physical device** — behaviour known to diverge from the emulator:
     audio routing, background/interruption handling, push delivery,
     performance on low-end hardware.
  5. **Perceptual judgement** — "does it feel responsive", "does the
     output sound/look right". A human sense is the instrument.

  No listed reason → the tag is invalid → find the agent-runnable
  version or say why none exists.

**Every `[human]` case is a step-by-step script**, complete enough to
run without asking anything back:

```
TC-3.2b [human — real sensor input]
Setup: build <exact build>, test account <which>, environment <which>
1. <action>
   → Expected: <observable outcome at this step>
2. <action>
   → Expected: <observable outcome>
On failure: <what to capture — screenshot, exact time for log joins, which step>
```

Per-step expected results (not one expected at the end), preconditions
with the exact build/account/environment, and an "on failure, capture…"
line so the bug report needs no second round. Estimate minutes per
script.

**Every plan/checklist ends with the summary table:**

```
[agent] N cases — run, results attached (X pass / Y fail)
[human] M cases — scripts ready, ~Z minutes estimated
Not covered: <named blind spots and why>
```

## Job 1 — Test plan from spec

1. **Get the AC.** Preferred source: the business-analyst spec (US-n /
   US-n.m IDs). No spec → read the PR description and the diff,
   reconstruct the AC yourself, and mark every one **reconstructed — not
   approved**; reconstructed AC the stakeholder later corrects are
   cheap, silently-assumed behaviour is not.
2. **Risk-rank before writing cases.** Depth follows risk, not story
   order. Deepest first: money/entitlement correctness → cross-repo
   contracts → the product's core loop → data written to user state →
   presentation. A cosmetic story gets one case; a grant/charge path
   gets its boundaries, its idempotency, and its failure modes.
3. **Write cases with traceability.** `US-1.2 → TC-1.2a, TC-1.2b…`.
   Then run both audits: every AC has ≥1 case (a gap is a finding, not
   a silent omission), and every case points at an AC — or at a named
   risk ("TC-R1: double-claim idempotency, no AC covers it"), which is
   also a finding for the spec.
4. **Case shape:** id · AC/risk it traces to · `[agent|human — reason]`
   · preconditions · steps with per-step expected · covers which
   boundary (happy / error / boundary value / concurrency).
5. **Run the `[agent]` cases now** — a plan whose runnable half is unrun
   is a draft. Attach results; failures become bug reports (job 3
   shape).

## Job 2 — Pre-release regression checklist

Derived from what changed, never copied from last time:

1. Read the release queue and each queued item's actual diff — the
   checklist covers *these* changes and their blast radius, not the
   whole product.
2. For each item: what does it touch (repo, flow, table, event)? Which
   cross-repo contract? Contract-touching items get a **mandatory
   integration verify on the dev environment** (job 5 method) — a
   contract row ticked from unit tests alone is a red flag.
3. Add the standing high-risk floors regardless of diff: the
   purchase → entitlement → display chain, login/session start, and one
   pass of the product's core loop end-to-end. Cheap, and they catch
   the expensive class.
4. Note the ship vehicle per item — if the workspace distinguishes
   hot-updatable from store-release changes, a checklist item testing
   what this vehicle cannot even change is itself a finding.
5. Output: checklist grouped by [agent]/[human], summary table, and an
   explicit "not covered" list. Hand it over; **never proceed to any
   release tooling yourself**.

## Job 3 — Bug intake & repro

1. **Pin the coordinates first:** exact build/version, platform, OS,
   environment, account tier, timestamp. A bug without coordinates is a
   rumor. (Check test-surface.md for version-specific traps — e.g.
   builds whose crash symbols were never uploaded.)
2. **Hunt evidence before reproducing:** the error tracker and the
   analytics trail around the reported time (`docs/personas/
   data-access.md`). Evidence narrows the repro from "somewhere in the
   product" to a branch.
3. **Reproduce deliberately:** same environment/tier/state, on dev or
   emulator. Distinguish and report honestly: **reproduced** (steps
   below) / **not reproduced** (what was tried, what differed from the
   reporter's coordinates) / **cannot attempt** (needs a `[human]`
   reason — then write the script). "Could not reproduce" is a status,
   not a dismissal — one user's crash with tracker evidence is real
   regardless.
4. **Bug report shape:** title (symptom, not guess-at-cause) ·
   coordinates · steps to reproduce · expected vs actual · evidence
   links · severity · scope guess (how many users, via product-analyst
   discipline if it matters) · suspected area (labeled hypothesis —
   root-causing is the fixer's job; your leads are welcome but tagged).
5. **Severity ladder — consequence to the business, not reporter
   volume:**
   - **S1** — users lose money/entitlement they paid for, data loss,
     crash on a main path, security. Interrupts anything.
   - **S2** — a paid feature or the core loop broken for a segment;
     silent analytics corruption (wrong numbers steer wrong decisions).
   - **S3** — degraded UX on a real path, workaround exists.
   - **S4** — cosmetic, rare-branch, polish.

### Job 3b — Fix verification

1. **Reproduce the original bug first** — on the pre-fix code or via
   the original evidence trail. If the original was never reproduced
   and can't be now, say so: verification below is then weak, and the
   report must carry that caveat instead of a clean "fixed".
2. **Run the exact broken path** on the fixed build: same steps, same
   coordinates. Pass *here* is what "fixed" means.
3. **Regress the neighbours:** whatever the fix touched, walk that
   flow's adjacent branches — fixes to shared code break the sibling
   branch, one level out from the change.
4. **Ask "where should this have been caught?"** A bug a test should
   have stopped yields a companion finding ("missing test for X" —
   name the suite and the case). A lesson about *method* (a class of
   bug, not one bug) routes to `skill-coach` for the relevant skill's
   references.
5. Verdict: **verified-fixed / not-fixed / can't-verify (+ reason)**,
   with the neighbour regression list attached.

## Job 4 — Exploratory charter

Structure the hunch, then hunt:

1. **Charter:** "Explore <area> with <resources/env> to discover <risk
   class>" — one charter per session, timeboxed (~45–60 min of human
   time, or one agent pass), findings logged as they happen.
2. **The standing tour list** — recurring edge classes worth a tour
   through any new feature (adoption adds the product's own):
   - **Interruption tour:** notification/call mid-flow, app
     backgrounded mid-operation, network drop mid-request, kill and
     relaunch mid-flow.
   - **Limits tour:** hit a quota/cap mid-use, cross a boundary value,
     plan/tier change while a session is open.
   - **Identity tour:** account switch on the same device, logout
     mid-flow, expired session on relaunch, fresh install vs upgrade.
   - **Permission tour:** deny then use the feature, deny then grant in
     Settings, consent-dialog timing (`[human]` where dialogs are
     native).
   - **Version tour:** old client + new server and new client + old
     server for any served-field change; hot-updated build vs store
     build divergence, where the platform has both.
   - **Locale/content tour:** language switch mid-flow, glyph rendering
     for the product's scripts, empty/missing content states.
3. Findings that are bugs get the job-3 shape; observations that are
   spec gaps route to business-analyst; "this felt wrong but works as
   specced" routes to product-owner as UX input, clearly labeled.

## Job 5 — Integration & contract testing

Unit suites passing on both sides proves the mocks agree with
themselves. This job tests the seams:

1. **Pick the seam from the change:** which endpoints/DTOs/events cross
   repo lines? The workspace's cross-repo contracts doc names the
   standing ones; the diff names the rest.
2. **Verify the contract at the wire, not the mock:** run the client
   against the dev server (or call the dev server directly and diff the
   response shape against what the client parses). Shape drift,
   nullability drift, and enum-value drift are the standing suspects.
3. **Walk one real end-to-end path** on the dev environment for the
   touched flow: auth → the feature → the state it writes (row, grant,
   event) — then check the written state, not just the 200.
4. **Deploy-order test:** for served fields, simulate the lag windows —
   new server + old client (must degrade gracefully, not crash) and new
   client + old server (a missing field must not silently zero a
   user-visible value unless that fallback was *decided*). The
   silent-degradation finding is the most valuable output of this job.
5. **Suite gap analysis** (when asked, or when a seam bug is found):
   name where coverage is mock-only, and propose the *few* integration
   tests worth their maintenance — ranked by the job-1 risk ladder,
   never "add integration tests everywhere".

## Reporting discipline

- The report leads with the verdict table (AC-by-AC or checklist-item
  status), then bugs by severity, then **the blind-spot list** — what
  was not tested and why. The blind-spot list is mandatory; it is the
  half of the risk information most reports omit.
- Pass/fail language is earned: "pass" means the case ran and matched
  expected, on a named build/environment. "Looks fine" is not a status.
- QA states risk; it does not say "OK to ship". The closing line offers
  the information; the decision goes to the owner ("3 S3 bugs open,
  blind spots X and Y — the ship call is yours/product-owner's").
