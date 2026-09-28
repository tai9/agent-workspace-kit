# Delivery method

The working method per job, the two ladders, the ordering rule, the
scoping rules that keep a large tracker readable, and the required
shapes. A shape with an empty slot is unfinished; a slot that cannot be
filled is itself a finding ("this issue has no owner and no acceptance
criteria" is a real and useful sentence).

Every command below runs through `direnv exec "$WS" gh …` — see the
auth section of SKILL.md. `$WS` is the workspace root. Issues are
identified as **`repo#n`**, never bare `#n`: in a multi-repo workspace a
bare number names three different issues.

## Scoping the pull — read this before any command

A tracker of any age holds thousands of closed issues and hundreds of
open ones. At roughly 0.5 KB of JSON per issue, 500 open issues printed
into the conversation is ~65k tokens of context spent on a list nobody
reads. **Only what you print costs context; what you write to a file
costs nothing.** Every job obeys these six rules.

**1. Closed issues are never swept.** They answer no question about the
present. Touch them only through a narrow server-side filter, with a
stated purpose:

- milestone scope — `--milestone "<title>" --state all`
- what actually landed in a period — `--search "closed:>=<date>"`
- one issue by number.

**2. One fetch per engagement, into a file; then query the file.**

```sh
mkdir -p .pm-cache
direnv exec "$WS" gh issue list -R <owner/repo> --state open -L 1000 \
  --json number,title,labels,assignees,updatedAt,milestone,blockedBy,blocking,parent,closedByPullRequestsReferences \
  > .pm-cache/<date>-<repo>.json
```

Every slice after that is `jq` over the file — stale, blocked,
unassigned, by label — with no second network call and no second
context cost. `.pm-cache/` is gitignored; the snapshot is disposable,
the readout in `docs/pm/` is not.

**3. Two tiers, always in this order.**

- **Aggregate tier** — always computed, always printed, ~15 lines:
  totals by status, by assignee, by label, and an age histogram (fresh
  / 7–30 days / >30 days). This is what a 500-issue board is allowed to
  cost.
- **Detail tier** — only rows that must be read one by one: in flight,
  blocked, at risk, done-not-closed, and the 3–5 next-up candidates.
  **Hard cap ~40 rows.** Over the cap, tighten the filter; never print
  a longer list.

500 open issues are *counted*; the ~70 that are moving are *listed*.
Job 3 draws from triaged items, never from the whole backlog.

**4. Readouts are incremental.** Every `docs/pm/` readout stamps its
`as of`. The next one pulls the delta —
`--search "updated:>=<previous as-of>"` — plus everything still open
and blocked. A weekly readout over a 500-item board is a few dozen
changed items, not 500.

**5. The board is the working set; repo issues are the drift check.**
`gh project item-list` returns what is on the board — usually far
smaller than the repo's open issues. Start there. Sweeping repo issues
serves exactly one purpose: finding open issues that are *not* on the
board. Answer that as a count first (`N open issues off the board`);
list them only if N is small or the owner asks.

**6. Verify you got the whole page.** If the number of records returned
equals `--limit`, the page was truncated: raise the limit and rerun.
Never report from a page you did not confirm was complete. Defaults are
30 for both `gh issue list` and `gh project item-list` — always pass
`-L` explicitly.

## The complexity ladder

Complexity is read from evidence, not felt. Each size is defined by
what is true of the change, and the estimate names which of these it
matched:

| Size | What makes it that size |
| --- | --- |
| **XS** | One file or one config value, one repo, no contract, no schema, no new UI state. Reversible by revert alone. |
| **S** | One repo, a handful of files inside an existing flow. No cross-repo contract, no migration, AC already exists or is obvious. |
| **M** | One repo but a new flow or new state, **or** two repos with no contract change between them. Needs test cases written; may need a design decision. |
| **L** | Touches a cross-repo contract, **or** carries a data migration / schema change, **or** needs AC and design that do not exist yet. Ships in a coordinated order across repos. |
| **XL** | Any of the L conditions plus an irreversible edge: data that cannot be migrated back, a store release that cannot be OTA-patched, a third-party or billing integration, or a device-only surface that cannot be verified before release. Decompose before scheduling. |

Signals to read, in this order: the files the flow lives in
(`docs/personas/flow-map.md`), whether the workspace's cross-repo
contracts doc names anything it touches, whether it changes persisted
shape, whether AC exists, whether it can be verified without a physical
device or a real purchase (ask `qa-engineer` if unclear).

**Tag every estimate** `verified` (you opened the code, the diff, or
the contract — and say what made it that size) or `assumed` (read from
title, labels, or the reporter). An `assumed` L or XL is a request to
look before anyone schedules it. Reading code to size an item is
allowed and expected; *which repos and contracts a change touches* as a
requirements question belongs to `business-analyst` — you read it to
size, they read it to specify.

**XL never goes on a plan whole.** Decompose it into items that each
land independently, or the estimate is the only thing that ships.

## The priority ladder

Priority is consequence, not volume of complaint:

| P | Meaning | Response |
| --- | --- | --- |
| **P0** | Production is losing money, data, or access right now: crash on a core path, payment or entitlement broken, data corruption, security exposure. | Interrupt current work. Everything else waits. |
| **P1** | A committed outcome misses unless this moves: blocks a milestone, blocks other people's work, or a significant user segment is degraded with no workaround. | Next in, ahead of anything not P0. |
| **P2** | Real value, no deadline pressure, and the world survives another cycle without it. | Scheduled normally. |
| **P3** | Worth doing when it is cheap or nearby. Nice-to-have, cleanup, speculative. | Batched, or closed honestly if it will never be done. |

Whether a feature deserves to exist at all is not on this ladder — that
is `product-owner`. This ladder ranks work already agreed to.

Escalation is by evidence: a P2 that starts blocking two other items
becomes P1 because of the block, and the write records why.

## Priority is not order

The order to solve in is computed, and it differs from the priority
ranking whenever any of these apply:

1. **Hard dependency** — B cannot start until A lands. A comes first
   even at a lower priority.
2. **Unblock value** — an item that unblocks N others earns its place
   above its own priority. Say the N.
3. **Cross-repo lead time** — in a multi-repo workspace the side others
   consume (usually the service/contract side) ships first, so the
   other side is never waiting on a merge it cannot see.
4. **Reversibility** — between two items of equal priority, the
   reversible one goes first; the irreversible one gets the extra
   verification time it needs.
5. **Cost of the switch** — items in the same flow batch together
   rather than interleaving with unrelated work, unless a P0 says
   otherwise.

If the resulting order is identical to the priority column sorted, you
did not sequence anything — say so explicitly, or look again.

## Job 1 — Status readout

1. Preflight the account and the project scope (SKILL.md). Read
   `docs/personas/tracker-surface.md` for which board and which repos
   are authoritative, and for the stale threshold.
2. **The board first** (rule 5):
   ```sh
   direnv exec "$WS" gh project item-list <n> --owner <org> -L 500 --format json \
     > .pm-cache/<date>-board.json
   ```
   Then the repos' open issues into per-repo files (rule 2). Across
   many repos, one call covers them all:
   `gh search issues --owner <org> --state open -L 1000 --json repository,number,title,labels,assignees,updatedAt`.
3. **Cross-check against the repos, always** — the board is the claim,
   the repo is the evidence. Per repo, by merge date:
   ```sh
   direnv exec "$WS" gh pr list -R <owner/repo> --state merged -L 200 \
     --search "merged:>=<date>" --json number,title,mergedAt,closingIssuesReferences
   ```
   Never run `gh pr list` without `-R` from the workspace root: it
   resolves the repo from the current directory and will answer about
   the wrong one, or fail. `closingIssuesReferences` gives
   done-but-not-closed directly; `closedByPullRequestsReferences` on
   the issue side gives the same fact from the other end.
4. Age everything. `updatedAt` is the cheap signal; for in-flight items
   the age that matters is since the last actual commit, PR, or
   comment.
5. Print the aggregate tier, then the detail tier under the cap (rule
   3). Anything blocked feeds job 4.

**Status block — required shape:**

```
**As of:** <date> · account <login> · board <org/project #n> · repos <list>

**Totals** open N (in progress A / blocked B / todo C) · age: fresh X / 7–30d Y / >30d Z
  plus by-assignee and by-label counts — the aggregate tier

**Now** (in flight)
| Item | Owner | Age | Size | P | Evidence |
  Item = repo#n · Evidence = the last commit/PR/comment that proves it is alive, or "none in N days"

**Blocked**
| Item | Waiting on | Since | Unblock action | Whose |

**At risk**   items whose age, size or blocker says they miss what they were meant to make

**Done, not closed**   merged/shipped but still open — with the write that closes them

**Next up**   the top 3–5 from job 3, each with one line of why here

**Not visible to me:** <repos, boards, trackers, or untracked work outside this readout>
```

## Job 2 — Triage

Per issue, in one pass: restate it in one line (if you cannot, the
issue is underspecified — say so and ask); assign area/repo from the
flow map; assign complexity with its tag; assign priority with the
consequence that justifies it; check for duplicates and near-duplicates
by flow, not by title; name what is missing (no AC, no repro, no
owner).

Outcome per issue is one of: **ready** (sized, prioritized, has enough
to start), **needs AC** → hand to `business-analyst`, **needs a value
call** → hand to `product-owner`, **needs repro** → hand to
`qa-engineer`, **duplicate** → `gh issue close <n> -R <repo>
--duplicate-of <m>`, **wrong repo** → `gh issue transfer <n>
<owner/dest-repo>`, **decompose** (XL) → the child items you propose
(`gh issue edit <child> -R <repo> --parent <n>` links them).

Then write the fields — board fields through `item-edit` with the IDs
from `tracker-surface.md` (see job 5). Five or more items →
intended-change table first.

## Job 3 — Solve order

Input: the ready items from triage plus whatever is already in flight —
never the whole backlog.

1. Build the dependency edges first — from `blockedBy` / `blocking` /
   `parent` in the snapshot, from the contracts doc, and from the flow
   map. An edge that exists only in someone's head is the normal case;
   job 4 writes it down.
2. Apply the ordering rules above, in that order.
3. Output a shortlist of 3–5, each with: position, item (`repo#n`),
   size, P, and **the rule that put it there** ("ahead of api#12
   because it unblocks api#12 and app#19"). An entry whose reason is
   only its priority is fine only when no rule applied.
4. Say what you deliberately left out of the shortlist and why — the
   omissions are the part people argue with, so make them visible.

## Job 4 — Blocker & dependency sweep

Read the edges from the snapshot's `blockedBy` / `blocking` / `parent`
fields first; they are the ones GitHub already knows. For every blocked
item produce the full edge: **what it waits on → who owns that → since
when → the single next action that removes the wait → whether that
action is itself a tracked item**. A blocker whose unblock action is
not tracked is the finding: open it.

**Every edge you discover that GitHub does not know gets written back:**

```sh
direnv exec "$WS" gh issue edit <n> -R <owner/repo> --add-blocked-by <m>
```

That is what turns a one-off sweep into a wait graph the next readout
can read for free.

Cross-repo waits get special attention. Read the workspace's cross-repo
contracts doc, and check whether the blocking side has merged something
the waiting side has not consumed — a dependency already satisfied but
unnoticed is common and free to fix.

Circular waits are reported as circular, with a proposal for which edge
to cut (usually: ship one side behind a flag).

## Job 5 — Board hygiene

Board writes need four IDs, all recorded in `tracker-surface.md` during
adoption (project ID, and the field/option ID table):

```sh
direnv exec "$WS" gh project item-edit \
  --id <item-id> --project-id <project-id> \
  --field-id <field-id> --single-select-option-id <option-id>
```

One field per invocation. Item IDs come from the `id` key of
`item-list` output. Adding an issue to the board is
`gh project item-add <n> --owner <org> --url <issue-url>`.

| Drift | Fix |
| --- | --- |
| Merged, and the tracker's definition of done is "merged" | `gh issue close <n> -R <repo>` with the PR link |
| Merged but done means "released" | Move Status to the board's shipped-pending state — **never Close**. `agent-workspace-kit release status` lists what is merged but unshipped |
| Issue closed, work not actually done | Reopen, say what is missing |
| In progress, no activity past the stale threshold | `gh issue comment <n> -R <repo> --body "@<assignee> …"` — ask first. Move it back to ready only on a later engagement, after the ping went unanswered |
| Open issue not on the board | `gh project item-add`, or record why it is deliberately off |
| Missing Status / Priority / Size | Fill from triage |
| Assignee who is not working on it | Clear it — a false owner hides an unowned item |
| Label vocabulary drifting from the conventions | Normalize to `tracker-surface.md` |

**The definition of done in `tracker-surface.md` governs every Close in
this table.** Closing merged-but-unreleased work in a workspace where
done means released is the one mistake in this job that a 5-item sweep
can make fifty times.

Report as a drift table, then write. Five or more → intended-change
table first, then the writes, then echo the commands — and both the
table and the commands go into the engagement doc, not only into chat.

## Job 6 — Milestone readout

Milestones are per-repo objects; in a multi-repo workspace "the
milestone" is one title repeated across repos, or an iteration field on
the board (`tracker-surface.md` records which). Pull scope per repo:

```sh
direnv exec "$WS" gh issue list -R <owner/repo> --milestone "<title>" --state all -L 500 \
  --json number,title,state,closedAt,labels,assignees
direnv exec "$WS" gh api repos/<owner/repo>/milestones --jq '.[]|{title,due_on,open_issues,closed_issues}'
```

Scope committed vs. landed vs. remaining **by size, not by count** —
five XS and five L are not the same remaining work. Then: burn evidence
(what actually landed in the last period), the items at risk with the
reason, and the blockers that decide the outcome.

Ends with an explicit call: **on track** / **at risk — these N items
decide it** / **will miss — cut X, or move the date**. A percentage
without a call is not a readout.

Where the workspace ships through the kit's release layer, the
inventory of merged-but-unreleased work is `agent-workspace-kit release
status` — read it, and note anything landed but unshipped. **Never run
release tooling that changes anything**; a readout is an input to a
release, not a trigger for one.

## Hand-offs

| What surfaced | Goes to |
| --- | --- |
| "Is this worth building / worth it now" | `product-owner` |
| No AC, or AC that cannot be built from | `business-analyst` |
| "The number on the dashboard is wrong" | `product-analyst` |
| Needs a repro, or "is it actually fixed" | `qa-engineer` |
| A UX/visual question inside an item | `designer` |
| A competitor or benchmark question | `market-researcher` |
| This skill itself got something wrong | `skill-coach` |
