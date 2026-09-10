# {{NAME}} release process

The single source of truth for how a {{NAME}} change goes from a merged branch
to users. The **anchor's version is the anchor** — every release/patch is
named by it.

The actual ship mechanics (native release vs. OTA patch, the version gate) are
documented in the anchor repo's own runbook; this doc owns the **workflow and
cross-repo coordination** around them.

## TL;DR

```
feat/fix/chore worktree off trunk  ──squash-merge──▶  trunk
                                                        │
                                          agent-workspace-kit release add
                                          (record the squashed commit in
                                           UNRELEASED.md, classified 🟢 OTA
                                           or 🔴 Store, coupling flagged)
                                                        │
                                          …items accumulate; you don't ship
                                           one-by-one…
                                                        │
                        when ready: agent-workspace-kit release cut
                        ──pick items──▶  patch or release
```

- **`agent-workspace-kit release add`** after every squash-merge into the trunk.
- **`agent-workspace-kit release status`** to see the unreleased inventory.
- **`agent-workspace-kit release preflight <env>`** then
  **`agent-workspace-kit release cut`** when shipping.

## Branching model

- Every `feat/`, `fix/`, `chore/`, … is a **worktree branched off the trunk**,
  in the anchor repo and (for coordinated features) any paired repos. Paired
  branches share a name across repos.
- **The trunk is the single integration/test branch** — everything is
  verified there before it ships. Branch off it, PR into it. A PR opened
  against any other branch is invisible to `release add` and silently misses
  the next patch/release.
- Some workspaces keep a separate branch that mirrors what is actually live
  on the stores. That branch is not an integration branch and nothing is
  developed against it; it only moves once a release is actually live.
- An **item** = the **squashed commit on the trunk** from merging one branch.
  That squashed commit *is* the item's full diff and is what gets classified,
  recorded, and (for patches) cherry-picked.

## Classifying an item: 🟢 OTA vs 🔴 Store

A patch ships only the diff against the already-released runtime; anything
native must go through a store release. `release add` runs this rule
automatically; the manual form is:

```sh
git show --name-only --format= <commit> | grep -iE '<release.store_paths from workspace.yml>'
# no output → 🟢 OTA   |   any match → 🔴 Store
```

| Channel | What it is | How it ships |
| --- | --- | --- |
| 🟢 **OTA** | Logic/UI/copy-only, no native touch | an over-the-air patch — no build bump, applies on next cold launch |
| 🔴 **Store** | Any native change, or any bundled-asset touch | a full native build + store upload, and a minimum-build bump when older builds must not run against it |

## The inventory and the files

- **`releases/UNRELEASED.md`** — the rolling inventory of merged-but-unreleased
  items. `add` appends here; `cut` moves picked rows out. One row per item:
  channel, type, summary, commit(s), coupled.
- **One file per ship event**, named by the anchor's version:
  - **release** → `releases/<version>.md` (the store base).
  - **patch** → `releases/<live-version>.patchN.md`, N incrementing per patch
    onto that base build.
- The **live baseline** is marked by a `released/<version>` git tag in the
  anchor repo, and **patches stack on it**. A store release sets the tag to
  the new build's commit; each OTA patch then advances the tag to that
  patch's tip, so the next patch builds on the last one instead of silently
  dropping prior patches.

Each note keeps the established schema: header (version / date / **status**),
Promotional Text, What's new (store copy), Changelog (with channel + commit),
Release dependencies, Verification, Scope. Status and timestamp are updated
on every change.

## Cutting a release

```sh
agent-workspace-kit release preflight production --mode release
agent-workspace-kit release cut release production both [--distribute] [--at <trunk-commit>]
```

`release cut release`:
1. Spins a clean worktree at the chosen trunk commit (default HEAD).
2. Runs the anchor's own release wrapper there (bumps the build, carries OTA
   items along, optional store upload).
3. Commits the version bump back to the trunk and tags `released/<new-version>`.
4. Writes `releases/<new-version>.md` and removes the shipped rows from
   `UNRELEASED.md`.
5. Removes the worktree.

Then, **always**:
1. **Fill the "What's new" section** in `releases/<new-version>.md` — replace
   the TODO placeholders with real user-facing copy and paste it into the
   store listing. Never submit a release with the template TODOs left in.
2. **Fill the "Promotional Text" section** the same way, where the store
   supports it.
3. Upload the store artifact(s) / promote to the production track.
4. Bump the minimum supported build, if configured, when older builds must be
   force-updated.
5. `git push --tags`.

And once the build is **actually live** — not when it is submitted, not when
it is in review:

6. Run `agent-workspace-kit live <version>` — reporting is the default; the
   writes are opt-in flags. It flips the note's Status, pushes the
   `released/<version>` tag if it isn't on origin, and (when configured)
   merges that tag into the mirror branch and bumps the version-gate config.

## Cutting an OTA patch

Because a patch ships against the **live base**, not trunk HEAD, you can
hotfix even when the trunk already holds unreleased native items:

```sh
agent-workspace-kit release preflight production --mode patch
agent-workspace-kit release cut patch production android --items "2 4" [--allow-asset-diffs]
agent-workspace-kit release cut patch production ios     --items "2 4" [--allow-asset-diffs]
```

`release cut patch`:
1. Spins a worktree at the `released/<live-version>` tag (the live baseline —
   the tip of the last patch, not the store commit).
2. **Cherry-picks only the picked OTA commits** onto it (refuses any 🔴 Store
   pick — those need a release). Unreleased native items stay on the trunk.
3. Runs the anchor's own current patch wrapper from the worktree.
4. **Advances `released/<live-version>` to this patch's tip** so the next
   patch stacks on top.
5. Writes `releases/<live-version>.patchN.md` and removes the shipped rows
   from `UNRELEASED.md`, then removes the worktree.

> **Coupling caveat.** If an OTA commit depends on a 🔴 Store commit, the OTA
> one can't cleanly separate — it either waits for the store build too, or
> ships as a hand-resolved hybrid. Keep OTA-eligible work self-contained to
> avoid this.

## Recording an item (run after every squash-merge)

```sh
agent-workspace-kit release add                 # records trunk HEAD (the squash commit)
agent-workspace-kit release add <commit>        # a specific commit
agent-workspace-kit release add <commit> --be <other-commit>   # coordinated cross-repo item
```

`agent-workspace-kit release preflight` runs `agent-workspace-kit doctor` as
one of its checks: workspace drift — a rules file nobody reads, agent config
that died with a clone, an env key documented nowhere — fails the pre-flight
rather than riding along into the build. `agent-workspace-kit check` runs the
same doctor alongside shellcheck and the release-tooling tests; run it before
changing anything under this kit's config.

A `pre-commit` hook refuses a commit made while the trunk is checked out,
pointing at the worktree flow instead (`--no-verify` overrides it, which is
how the release tooling commits its own version bump). A non-blocking
`post-merge` hook prints a reminder to run `release add` when the trunk moves
to a commit the inventory doesn't list. Install both with
`agent-workspace-kit install-git-hooks`, and re-run that after a fresh clone —
`.git/hooks` is the one directory git cannot version, so the hook body is
kept in this kit and copied in. It's a convenience only; the workflow does
not depend on it.

## Release obligations

These are rules, not options — every store release is incomplete until all
of them hold.

- **Every production release MUST fill the "What's new" store copy.** After
  `release cut release` writes `releases/<version>.md`, always replace the
  "What's new" TODO placeholders with real user-facing copy and paste it into
  the store listing before submitting. Never ship a release with the
  template TODOs left in — this is a required release step, not a follow-up.
- **Every production release MUST also fill the "Promotional Text" store
  copy**, where the store supports it. Write one selling sentence leading
  with that build's headline benefit. It must never be left at the previous
  release's pitch or at the template TODOs.
- **Every production release MUST be tagged (and the tag pushed).** No
  untagged prod release. The anchor cut creates `released/<version>` via
  `release cut` (don't hand-make it). Any paired repo that deploys
  continuously with no auto-tag should be tagged by hand after deploying,
  with the version it ships alongside.
- **`release cut` is the only sanctioned way to cut a store release; do NOT
  run the anchor's native release wrapper directly as the release.**
  `release cut release` does three things the wrapper alone does not: writes
  `releases/<version>.md` from the template, moves the shipped rows out of
  `UNRELEASED.md`, and creates the `released/<version>` tag. Invoking the
  wrapper directly silently skips the release note, the inventory update, and
  the tag. If you ever must bypass `release cut` (e.g. a hotfix build), you
  OWN those three artifacts by hand, as part of the same task — not as a
  follow-up: (1) create `releases/<version>.md` from
  `releases/_TEMPLATE.base.md` with real "What's new" copy filled in (never
  leave the TODOs), (2) clear the shipped items from `UNRELEASED.md`, and
  (3) tag + push `released/<version>`. A store build with no release note is
  an incomplete release.
