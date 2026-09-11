# Decision playbook

How each verdict type gets made. Read the section for the decision at
hand; the verdict shape lives in SKILL.md. Product-specific inputs come
from `docs/personas/`: the strategy doc, prior findings, and the domain
playbook (whose risk section is priced into every verdict).

## Go/no-go — the interrogation

Run the proposal through these in order; the first hard failure usually
ends the discussion.

1. **Path to the north star.** Trace the causal chain from this feature
   to the north-star outcome, step by step. "Engagement" is not a step;
   "user hits limit X on day 3 and sees the paywall with a concrete
   reason to pay" is. If the chain needs three optimistic leaps, say so.
2. **Who is it for?** Name the ICP segment from the strategy doc. If
   the honest answer is "everyone" or "power users" (already
   converted), the feature is unfocused or redundant.
3. **Moat test.** Does it feed the loop the strategy doc names as the
   moat, or is it a me-too feature from a competitor? Me-too carries
   the burden of proof: their feature works at their scale, with their
   economics, for their user — name the reason it transfers (a
   `market-researcher` synthesis proposal arrives with this argument
   pre-made; hold it to the same standard).
4. **Has it been tried?** Check prior-findings. A reverted experiment
   re-proposed without addressing why it failed is an automatic no.
5. **Cost side.** Marginal-cost delta (the domain playbook's unit
   economics — who gets the expensive resource, and how much), team
   opportunity cost (what does NOT get built), and ship path. A feature
   can pass 1–4 and still lose here.
6. **Perverse incentives.** What does this reward, exactly, and can it
   be farmed? Metrics users can inflate get inflated; idempotency and
   caps are scope, not polish.

Small-N discipline: at small scale most feature effects are
statistically invisible. Prefer verdicts whose success metric is
observable now (behavioural counts, funnel steps with dozens of users),
and say when an effect cannot be measured yet — "unmeasurable at our
scale" is an argument against building now.

## Prioritization — sequencing the backlog

Two refusal conditions before any scoring: **frameworks execute
strategy, they don't create it** — if the strategy doc can't say what
matters, no scoring model will, and the honest verdict is "strategy
first"; and **don't fix what isn't broken** — re-prioritizing a backlog
already being executed in a sane order is motion, not progress. Match
the tool to the situation: rich comparable data → RICE-style scoring;
speed over rigor → ICE; a genuinely strategic bet → argue from the
strategy doc, a scoring table would only launder the judgment.

Score candidates on three axes, then argue in prose (1–3 each, no fake
precision — the argument is what matters):

- **Impact on paying users** — direct conversion/retention-of-payers
  effect beats diffuse engagement.
- **Effort** — in real team-weeks, counting cross-repo contract work
  and store-release coupling, not just happy-path code.
- **Confidence** — verified evidence > prior art in this product >
  analogy from the category > hunch.

Sequencing beats scoring: a lower-scored item goes first when it
unblocks or de-risks a higher one, or when it ships OTA while the big
one waits on a store cycle anyway. Deliver an ordered list with the
reason for each adjacency, never bare scores. State what is
deliberately NOT on the list and why — a priority list that drops
nothing is a wish list.

## Scope cut — deciding how much to build

The feature is approved; the question is the smallest version that
tests its hypothesis.

- **Name the hypothesis first.** "Users will X so that Y" — the MVP is
  whatever makes that observable, nothing more.
- **Cut in this order:** admin/authoring UI (hand-edit data for v1) →
  settings and preferences (pick the right default instead) →
  secondary platforms and edge audiences → polish on rarely-hit
  states. Never cut: error states on the main path, the analytics
  events that measure the hypothesis, quota/entitlement correctness.
- **Phase by ship path:** if half the feature is OTA-shippable and half
  needs a store release, that is the phase boundary.
- **Quality survives the cut** — best version *of the small scope*. Cut
  features, not quality: two screens with real error handling beat five
  screens of happy path.

## UX / product tradeoff

Smaller decisions: where a gate fires, what a default is, which of two
flows wins.

- Decide from the ICP's first week, not the power user's — the target
  user quits at friction the founder no longer sees.
- Defaults are decisions: the default is what ~95% experience; "make it
  a setting" is usually a refusal to decide.
- If the tradeoff touches free-tier limits, paywall placement, or what
  free users get — that is `conversion-audit` territory; hand over
  instead of freelancing an answer.

## Post-launch review — keep / iterate / kill

1. **Retrieve the preregistered metric and threshold** from the
   original verdict. If none exists, define one honestly *before*
   looking at the data — deciding the bar after seeing the number is
   how zombie features survive. The evidence itself is
   `product-analyst`'s post-ship readout (reach / depth / impact
   against the criteria); commission it rather than re-deriving.
2. **Window** long enough to clear novelty — 2+ weeks post-ship,
   excluding launch-push days, gated on rollout adoption where the
   product ships staged.
3. **Verdict:**
   - **Keep** — met threshold; say what "good" looks like at next
     review.
   - **Iterate** — used but leaking at an identifiable step; name the
     ONE change and the new threshold. "Iterate" without a named change
     is "keep" wearing a disguise.
   - **Kill** — below threshold with no identifiable fix. Killing means
     removing the code and saying so; a hidden entry point still costs
     maintenance and contract surface. Record the lesson in
     prior-findings so it isn't re-proposed.

The default for a feature nobody uses is kill, not "leave it, it's
harmless." Every shipped feature is permanent contract surface.

## Anti-patterns — name the cost, not just the sin

| Anti-pattern | What it costs | Correct approach |
| --- | --- | --- |
| Solution-first thinking | Solves the wrong problem confidently | Start from the user problem; make the proposer state it (business-analyst job 1 exists for this) |
| Feature factory | Shipping velocity with no strategic compounding | Every GO traces to north star + ICP + moat, or it isn't a GO |
| Everything urgent | No prioritization is a priority decision made badly | An ordered list that drops something, with the reason |
| Framework laundering | A scoring table lending fake objectivity to a judgment call | Say "this is a strategy judgment" and argue it from the doc |

## Risk checklist — priced into every verdict

The domain playbook holds this product's specific list; these hold
everywhere:

- **Ship path:** anything native/store-gated costs a review cycle
  (weeks); the OTA-only version of the same idea costs hours — say
  which one the verdict assumes.
- **Cross-repo contract:** a feature touching a recorded contract is a
  multi-repo coordinated change — count that in effort.
- **Store rejection surface:** external payment links, prize-like
  rewards, unmoderated UGC, misleading claims. One rejection costs a
  cycle.
- **Marginal cost:** anything granting or encouraging the expensive
  resource has real per-user cost and competes with its paid SKU — do
  the math.
- **Abuse:** rewards keyed to farmable metrics will be farmed.

## Competitive check — when to look outward

Commission `market-researcher` (or search directly for a quick check)
when the proposal is a known mechanic and you need how it is
implemented *and monetized* by the closest competitors now, or when
"competitor X has it" is offered as the argument. Don't look outward
when the decision hinges on this product's own data or economics —
competitor behaviour is noise there.

Read competitor features adversarially: what they ship reflects their
scale, their unit economics, and their investor story. "The giant has
it" is evidence it works for the giant — name which of its properties
this product shares before transferring the conclusion. The moat doc's
me-too test applies: copy what feeds the loop, skip what decorates it.
