# agent-workspace-kit

The agent workflow this kit was extracted from, generalized so other projects can adopt it:
worktree discipline, one rules file, guard hooks, a drift doctor, and a
release layer with an unreleased inventory, `released/` tags and OTA patches.

Ships as a Claude Code plugin and a CLI from one shared core.

**v1 targets one thing:** a mobile app plus a backend, in either of two shapes —
sibling repos under a workspace root (multi-repo) or one repo with role
directories (monorepo). Nothing else.

Design: [`docs/design.md`](docs/design.md). Status: built and tested — see
`docs/design.md`'s Verification section. First consumers: this kit's own
origin workspace (multi-repo) and Foxy Junior (monorepo).

## Install

As a CLI, added to a workspace's own `package.json`:

```sh
pnpm add -D github:tai9/agent-workspace-kit   # while the repo is private
pnpm add -D agent-workspace-kit               # once published to a registry
```

Then set the workspace up:

```sh
pnpm exec agent-workspace-kit init
```

`init` detects the workspace's shape (multi-repo or monorepo), writes
`workspace.yml`, the `releases/` skeleton, the rules-file templates and the
git/Claude hooks, and reports what still needs filling in by hand (the
`contracts:` list, the preflight URL source, and anything it couldn't infer).
Run with `--dry-run` first to see the plan without writing anything, or
`--yes` to skip the interactive prompts.

As a Claude Code plugin, once the marketplace listing is public:

```
/plugin marketplace add tai9/agent-workspace-kit
```

That installs the workflow skills (`release`, `app-live`,
`workspace-doctor`), the `contract-reviewer` agent template, and the five
**persona skills** (below); the workflow skills call the same CLI under the
hood, so plugin and CLI never drift apart.

## Commands

All of them route through the one dispatcher, `agent-workspace-kit <command>`,
run from the workspace root:

| Command | What it does |
| --- | --- |
| `init [--yes] [--dry-run] [--root <dir>]` | Set a bare workspace up. |
| `doctor` | Report drift — read-only. |
| `check` | shellcheck + the test suite + doctor. |
| `release add [<commit>] [--paired [<repo>:]<commit>] [--dry-run]` | Record a merged-but-unreleased item. |
| `release status` | Print the unreleased inventory. |
| `release preflight <env> [--mode patch\|release] [--platform ios\|android] [--skip-doctor]` | Gate before a cut. |
| `release cut patch <env> <ios\|android> --items "<n ...>" [--commits "<sha ...>"] [--base <ver>] [--allow-asset-diffs] [--dry-run]` | Ship an OTA patch. |
| `release cut release <env> <ios\|android\|both> [--items "<n ...>"] [--at <ref>] [--distribute] [--dry-run]` | Ship a store release. |
| `live <version> [--platform ios\|android\|both] [--apply] [--merge-mirror] [--force-merge] [--post] [--post-args "<str>"]` | Report or apply a build going live. |
| `contract-check [<repo>] [<base-ref>]` | Which cross-repo contracts a diff touches. |
| `install-git-hooks [--dry-run]` | (Re)install the workspace's git hooks. |

`live` and `release cut` change nothing unless told to: no flags means a
report only.

## Persona skills

Six product-role skills ship with the kit: `product-analyst` (measurement),
`business-analyst` (requirements), `market-researcher` (competitors and
benchmarks), `product-owner` (build/priority verdicts), `conversion-audit`
(why-users-don't-pay diagnosis), `qa-engineer` (verification and risk
information). Each carries only the *method* — jobs,
disciplines, output shapes. What it knows about *your* product lives in
`docs/personas/` at the workspace root, which `init` scaffolds as stubs
(`templates/personas/`). A skill that finds its file still carrying the
`ADOPT-ME` marker runs **adoption** first: it explores the workspace,
interviews the owner, and fills the file — so the personas implement
themselves for each consuming repo, incrementally, on first use. The six
hand off to each other by name (analyst measures, owner decides, audit
diagnoses, BA specifies, researcher looks outward, QA verifies) and none
of them edits product code.

A seventh skill, `skill-coach`, maintains the layer itself: when a skill
gets something wrong, it classifies the failure (stale knowledge / wrong
method / rule not followed / not the skill's fault), applies the smallest
fix at the right layer — knowledge edits land directly in
`docs/personas/`, method changes need approval and route upstream to the
kit for kit-owned skills — and logs the lesson in
`docs/skill-lessons.md`.

## The two shapes

A workspace is either:

- **multi-repo** — sibling git repos under one workspace root, each with its
  own trunk: the anchor repo and the service repo, named in `workspace.yml`.
- **monorepo** — one git repo whose top-level directories play the same
  roles, sharing one trunk (Foxy Junior's shape: `app/`, `backend/`).

`workspace.yml` names the shape and the repo table; everything else in the
kit reads that table instead of assuming either shape. v1 ships two release
adapters: `flutter-shorebird` (Flutter app, OTA patches via Shorebird) and
`generic-semver` (anything else that keeps a plain semver version file).
