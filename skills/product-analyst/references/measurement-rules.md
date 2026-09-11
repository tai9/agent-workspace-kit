# Measurement rules

The non-negotiables. Generic here; the workspace's own instances of each
trap live in `docs/personas/data-access.md`, which holds the runnable
query shapes.

## 1. Users, not events

Distinct users, never bare event counts, for any question about people.
Report both when the ratio is itself the story — one user with forty
events is someone testing, not adoption. Know the join key between
analytics identity and database identity (data-access records it).

## 2. Dual-emitted events are swept before any total

When client and server can emit the same event name, totals double
silently. The affected list drifts every release: **regenerate it, never
trust a remembered one** — data-access carries the sweep query. Any
event emitted from both sides gets filtered to one side before it is
quoted. If the workspace has no such events, data-access says so
explicitly — absence of the note means unchecked, not safe.

## 3. Filter internal/test users, the right way around

Use exactly the filter the workspace's dashboards use (data-access
records it, including its failure mode — e.g. a property only ever set
to true makes `= false` silently drop everyone). An unfiltered hand
query disagrees with the dashboards, always in the flattering direction.

## 4. A zero has three meanings

"Never happens", "not instrumented", and "instrumented but broken" all
render as a flat zero. Before reporting a zero, check
`docs/personas/prior-findings.md`'s never-fired and does-not-exist
lists — and treat those lists themselves as stale-by-design: verify
against the live store. A zero on the wrong list is a data-quality
finding (job 9), not a user-behaviour finding.

## 5. Small N: the label never drops

- Under ~30 users in a denominator ⇒ every rate is tagged
  **hypothesis (N=…)**, with absolute counts shown.
- A percentage never appears without its fraction: "37% (3 of 8)".
- Know the volume at which one user's day moves a weekly line, and treat
  movements inside that band as noise until a segment or mechanism
  explains them.
- If pressed for a decision on thin data, give the decision the
  *structure* supports and keep the label on the *number*. Don't drop
  the caveat to sound decisive; don't hide behind it instead of
  answering.

## 6. Causal claims require ordering, not correlation

Never name WHY a metric moved until you have ruled out, in this order,
each with evidence:

1. **Instrumentation** — did the event die, rename, or start
   double-emitting mid-window?
2. **A cap, gate, or error** — did users stop because a limit, paywall,
   or failure stopped them? Event *ordering* answers this: what did
   affected users' sessions end with?
3. **Composition** — did the user mix change (new-vs-returning, segment,
   platform) rather than behaviour?
4. **The release timeline** — overlay releases, patches, pricing
   changes, incidents. A ship the same week is a candidate, not a
   conclusion.

Only a story that survives all four is stated as cause; anything less is
written **hypothesis**, in the doc and in chat.

## 7. Money is read from the ledger, not from client events

Revenue, trials, and conversions come from the source of truth
metrics-catalog names — almost always a server-side grants/transactions
ledger priced from a price table, never client purchase events (they
under-count server-to-server paths and double-emit). Separate paid from
trial from promotional before summing, and check for store-sandbox/test
purchases — at small volume one contaminates a month.

## 8. State is read from the live table, not from code or docs

Limits, prices, feature configs: quote the row and the date read.
Constants in code and figures in docs drift from the database — this
workspace's examples are in prior-findings.

## 9. Windows and comparisons

Default: last 28 days vs the preceding 28, half-open, in the timezone
the workspace's committed queries use — state the window even when
default. Never compare a partial period against a full one. When the ask
is a local calendar period and storage is UTC, compute reproducibly and
state the skew; shift boundaries only to match a comparison that did.

## 10. Proxies are named as proxies

Every workspace has stand-ins (a "session" for real usage, an
event-count funnel for a per-user one). metrics-catalog names the known
ones. Using a proxy is fine; using one silently is not.

## 11. Agree with the dashboards, or explain why not

The team's shared reality is its committed dashboards and admin pages. A
hand-rolled number that contradicts them is presumed wrong until you can
name the definitional difference; when both are right but defined
differently, the committed number is primary.

## 12. Privacy hygiene

Privileged reads select only needed columns; personal content stays out
of docs; aggregate before data leaves the store. Session replays, where
they exist, are watched by humans — never fetched or summarized blind.
