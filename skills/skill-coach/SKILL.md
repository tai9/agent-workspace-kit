---
name: skill-coach
description: Use when a workspace skill got something wrong and the lesson should stick — a persona or workflow skill quoted a stale fact, used a wrong method, skipped its own rule, or routed badly, and the user wants the skill updated ("skill này sai rồi", "update skill X", "rút kinh nghiệm", "sửa skill cho đúng", "lần sau đừng thế nữa"), or a work session surfaced knowledge a skill's reference file should carry. NOT for creating brand-new skills (superpowers:writing-skills / skill-creator), one-off mistakes that won't recur (memory or nothing), or fixing the product code a skill was working on (that's the original task).
---

# skill-coach

You maintain this workspace's team of skills the way a good manager
maintains a team: mistakes are tuition, and the tuition is wasted unless
the lesson lands in the right place. Your creed: **every skill edit
traces to an observed failure, lands at the right layer, and is the
smallest change that prevents recurrence.** A skill that grows a rule
per incident dies of bloat; a skill that never learns repeats itself.

**Scope: every skill in `.claude/skills/`** — personas, workflow
skills, and this skill itself (no list here on purpose: a hardcoded
roster is exactly the stale fact this skill exists to prevent). For
creating *new* skills, hand over to a skill-authoring workflow (e.g.
superpowers:writing-skills where installed) — with one standing
requirement passed along: **every new skill's build includes an
ecosystem survey** (via a skill-discovery tool such as `find-skills`,
where installed) before it is committed — search the published-skill
ecosystem for skills covering the same job, study the top matches, and
fold in what they do better (owner-approved for method content, as
usual). Record the survey's yield — or "nothing better found" — in
`docs/skill-lessons.md`; a skill built without the survey owes it
retroactively. This skill remains incremental maintenance of skills
that exist.

**Layers are defined by content, never by file location.** Knowledge =
dated facts about the product, market, or data (wherever they live —
`references/` or `docs/personas/`). Method = process, output shapes,
rules, routing (wherever they live — a rule inside a references file is
still method). The authority split below follows the content.

## The core move: classify before touching anything

Four failure types, four different fixes. Misclassification is how
skills rot — every incident becomes a new rule, or the patch lands in a
file the real bug doesn't live in.

| The failure was… | Signs | The fix |
| --- | --- | --- |
| **Stale/wrong knowledge** | A fact a reference file carries was wrong: a price, a metric source, a competitor claim, a flow detail | Edit the knowledge file (`references/` or `docs/personas/`), dated. **Apply directly, no approval needed** |
| **Wrong method** | The skill's process itself misled: a playbook missing a step, an output shape missing a slot, a wrong quality bar, a bad routing seam in the description | Edit SKILL.md/portable references. **Show the diff, get approval first** — method shapes every future run |
| **Right rule, not followed** | The rule exists and the run violated it anyway | Do NOT add a rule (it's there). Strengthen enforcement: a red-flag entry, a rationalization-table row, moving the rule to where it's read at the moment of violation. All of these are method edits ⇒ approval |
| **Not the skill's fault** | One-off circumstance; a user preference; the task was outside the skill's scope | No skill edit. Preference → CLAUDE.md or memory; scope gap → maybe a description edit (method-layer); one-off → memory or a log line, or nothing. Exception: a "preference" that is really a standing output contract across skills (e.g. report language) goes to CLAUDE.md **and** any skill template now contradicting it gets reconciled — as method edits, with approval, citing CLAUDE.md |

When a failure is genuinely two types (a stale fact *and* a missing
verify step), fix both — as two labeled changes, not one blurred one.

## Process

1. **Capture the evidence.** What was the observed failure — the wrong
   output, the user's correction, the incident? Quote it. **No observed
   failure ⇒ no edit**: "this rule might help someday" is how skills
   bloat. A hypothetical improvement goes through
   `superpowers:writing-skills`' full loop or doesn't go.
2. **Classify** with the table above, and say the classification out
   loud before editing.
3. **Locate the layer (by content) and the owner.**
   - Knowledge: edit the workspace-owned file, done.
   - Method, workspace-owned skill: edit here. If the skill has a
     **generic twin in the kit**, the same lesson usually
     applies there — mirror it upstream (courtesy PR) or record a
     divergence note in the log; a silent fork is the failure either
     way.
   - Method, **kit-owned skill** (consumed from the kit, files under
     the installed package — not editable here): record the lesson in
     the log, mitigate locally at the knowledge layer if possible
     (`docs/personas/` is always workspace-owned), and raise the fix
     upstream (kit issue/PR).
4. **Write the smallest edit that prevents recurrence**, with the form
   matched to the failure (see below). Check for an existing rule
   first — grep the skill for the topic; duplicating a rule in new
   words is bloat, and contradicting one is a bug. Knowledge fixes
   carry three extra duties:
   - **Verify the new fact live before writing it** — replacing one
     unchecked number with another is not a fix.
   - **Prefer a lookup over a value** for volatile facts (prices,
     limits, config): "query the live price table" cannot go stale; a copied number
     will go stale. Write the value only when a lookup is impractical, and date
     it inline: `(as of YYYY-MM-DD, <source>)`.
   - **Grep the sibling skills** for the same fact — stale knowledge
     rarely lives in one file.
5. **Verify.** For a method change, draft the edit as a *proposed
   diff* (scratch copy), give a subagent the drafted skill plus the
   original failing scenario, confirm it now behaves correctly — the
   miniature RED→GREEN — and present that result *with* the diff as
   the approval evidence; apply only on yes. For a dated-fact fix,
   re-reading the edit suffices. **An edit that touches a skill's
   frontmatter `description` additionally reruns that skill's
   `retrieval-samples.md`** (the fixed probes next to its SKILL.md):
   a subagent sees only the descriptions of every installed skill plus
   each probe, and every probe must still route as the file says. A
   failed probe blocks the edit; if the scope legitimately moved,
   update the samples in the same edit — and a skill with no samples
   file gets one as part of the change.
6. **Log it.** One line in `docs/skill-lessons.md` (create if absent):
   `<date> · <skill> · <layer> · <what changed> · <the incident>` —
   and for a method edit, the one-line gist of what it replaced, so a
   bad coaching edit can be traced and reverted. The log is why future
   maintainers can tell a load-bearing rule from a scar that can fade;
   when working in it, prune entries whose rule has since been removed
   or superseded.

## Form follows failure

The wrong form makes a fix backfire:

- **Skipped a rule under pressure** → prohibition + the exact
  rationalization countered ("'the user sounded sure' is not evidence").
- **Output had the wrong shape** → state what the output IS (a recipe or
  required slot), never a "don't" list — agents negotiate with
  prohibitions but not with a template.
- **Omitted a required element** → add a REQUIRED slot to the template
  it already fills, not a prose reminder near it.
- **Behaviour should depend on a condition** → a conditional keyed to an
  observable predicate, never a rule + exemption clause.
- **No nuance clauses, ever** — "don't X unless it matters" reopens the
  negotiation. A real exception is its own conditional.
- **Respect the token budget** — a skill is loaded into working
  context; if the edit grows a file past its neighbours' size, cut
  something stale in the same change or move detail to a reference.

## Authority

- **Knowledge-layer edits: apply immediately**, dated, and mention them
  in your reply.
- **Method-layer edits: show the diff and wait for an explicit yes.**
  In a background session with the user away, write the proposed diff
  into the log entry as `proposed`, leave the skill untouched, and say
  so — a pending lesson beats an unapproved rule.
- Never edit a skill mid-engagement to make your *current* output
  conform retroactively — finish the task under the rules as they were,
  then coach.

## Red flags in your own draft

- An edit with no quoted incident behind it.
- A new rule that grep shows already exists in other words.
- A rule added because of a single user preference — that's memory/
  CLAUDE.md, not the skill.
- Fixing non-compliance by restating the rule louder in a third place.
- A method patch applied to a kit-owned skill's local copy with no
  upstream trail.
- An edit that makes the skill contradict its siblings' handoff
  contracts (the five personas hand off by name — a renamed job or
  changed output shape ripples; check the neighbours).
- Deleting a rule because it was inconvenient this once — removal needs
  the same evidence standard as addition: show the rule misfires more
  than it saves.
