# agent-workspace-kit — design

**Status:** approved, not yet implemented — revised 2026-09-09 after the
workflow review landed (relay hooks, doctor, contract layer, test suite) and
after Foxy Junior was named the second consumer.
**Date:** 2026-09-09
**Consumers:** this workspace (VieSpeak, multi-repo) and Foxy Junior (monorepo)

## Problem

The workflow this workspace runs on is good and it is trapped here. Two layers
are worth extracting to a public repo other projects can adopt.

The **conventions layer** carries no VieSpeak in it at all: worktree discipline,
trunk rules, `CLAUDE.md` as the one rules file with `AGENTS.md` symlinked to it,
rules kept separate from feature reference, agent config under version control,
a doctor that reports drift, and a set of hooks that turn the dangerous commands
into confirmation prompts.

The **release layer** is a good model in a specific body. Of the 40 functions in
`scripts/lib/release-common.sh`, 34 are bookkeeping over markdown and are already
neutral. Six touch the ecosystem:

| Seam | Today | Becomes |
| --- | --- | --- |
| Version anchor | reads `pubspec.yaml` | adapter that reads and writes the version |
| OTA vs store rule | one fixed regex | a configured list of store-forcing paths |
| Coupling warning | one fixed regex | a configured list of contract paths |
| Repo paths | `APP_DIR` / `BE_DIR` constants | a repo table with roles and trunks |
| Preflight | two fixed endpoints | a URL source plus an endpoint list |
| Build and patch | calls Shorebird directly | adapter |

So the tooling does not need rewriting. Six constants need to move outward.

## Goals

- A public repo, `agent-workspace-kit`, that ships both a Claude Code plugin and
  a CLI from one shared core, so the two can never drift apart.
- A project adopts it with one install command and one `init` run, and keeps
  updating the kit without its own configuration being touched.
- **The full model, in both shapes.** The kit carries everything VieSpeak runs
  today: OTA patches via Shorebird, the unreleased inventory, `released/` tags,
  the mirror branch, the doctor, the contract check. A consumer that lacks one of
  these adopts it; the kit is not trimmed to fit a consumer.
- Two workspace shapes, chosen in config, nothing else varying:
  - **multi-repo** — sibling git repos under one workspace root (VieSpeak:
    `viespeak-app/`, `viespeak-be/`, `viespeak-landing/`).
  - **monorepo** — one git repo whose top-level directories play the same roles
    (Foxy Junior: `app/`, `backend/`, `packages/`).

## Non-goals for v1

- **Generalising the Supabase version gate.** It stays a project-supplied
  command run after a cut, not a concept the kit knows about.
- **`examples/` and CI for the kit repo.** Deferred. v1 is verified by the test
  suite plus parity against VieSpeak and a clean `init` on Foxy Junior.
- **A third shape.** Nothing that neither consumer needs.

## Layout

```
.claude-plugin/plugin.json    plugin manifest
skills/                       release, app-live, workspace-doctor,
                              and the five persona skills
agents/                       contract-reviewer (template)
hooks/                        guard-release, guard-pr-contract, doctor-on-start,
                              workspace-guards.stub (multi-repo relay)
git-hooks/                    pre-commit, post-merge
lib/                          release core + doctor + contract check — no ecosystem knowledge
adapters/                     flutter-shorebird, generic-semver
bin/                          the CLI: init, doctor, check
templates/                    rules-file skeleton, RELEASE_PROCESS skeleton,
                              release-note and UNRELEASED templates, settings.json
test/                         the shell test suite extracted from scripts/test/
docs/
```

`lib/` is the single source of truth. The plugin's skills call it; the CLI calls
it. Nothing is duplicated between the two halves.

## Configuration

One file at the consumer's workspace root, `workspace.yml`. It replaces the six
seams above and names the shape. Nothing else lives in it.

```yaml
shape: multi-repo               # or: monorepo

repos:
  app:
    path: viespeak-app          # multi-repo: a sibling git repo
    trunk: develop              # monorepo: one trunk, set once at top level
    role: release-anchor        # the repo whose version names every release
    mirror: main                # branch that tracks what is live; app-live moves it
  backend:
    path: viespeak-be
    trunk: main
    role: service
    deploy: continuous          # no version of its own; tagged with the anchor's

release:
  adapter: flutter-shorebird
  anchor_file: viespeak-app/pubspec.yaml
  tag: "released/{version}"
  store_paths:                  # any touch here forces a store build
    - android/
    - ios/
    - pubspec
    - .gradle
    - Podfile
    - Info.plist
    - AndroidManifest
    - assets/
  contract_paths:               # touching these warns about cross-repo coupling
    - lib/core/services/api_service
    - lib/core/services/app_version_service
  unreleased_prose_limit: 60    # doctor: max prose lines around UNRELEASED.md's tables

contracts:                       # optional; cross-repo pairs contract-check reports on
  - name: referral
    paths:
      app: lib/features/learn_together
      backend: referral

preflight:
  base_url_from: "env:API_BASE_URL@viespeak-app/.env.{env}"
  endpoints:
    - /health
    - /api/app/version-status
  extra:                        # optional, project-supplied; each must exit 0
    - "tool/preflight-env-store.sh"

post_release:                   # optional, project-supplied
  - "node scripts/bump-version-gate.mjs {version}"
```

### What the shape changes

| Concern | multi-repo | monorepo |
| --- | --- | --- |
| `repos.*.path` | a git repo | a directory inside the one repo |
| trunk | per repo | one, top-level `trunk:` |
| `released/` tag | on the anchor repo; services get `-beN` suffix tags | one tag on the repo |
| mirror branch | on the anchor repo | on the repo |
| Claude hooks | relay stub copied into every repo's `.claude/hooks/`, byte-identical to the kit's; doctor fails on drift | hooks live once, at the root; no relay |
| git hooks | installed per repo | installed once; if husky owns `.husky/`, the kit appends to its `pre-commit` and `post-merge` instead of setting `core.hooksPath` |
| contract paths | relative to each repo | relative to the workspace root |
| doctor "repo not cloned" | checked | skipped |
| `store_paths` match | against the anchor repo's diff | against the diff under the anchor `path` |

The release core never branches on shape. It asks the repo table for "the diff of
the anchor since the last tag", and the repo table answers differently.

## Adapter contract

An adapter is one shell file exposing three functions. Anything beyond these
three belongs in the core, not the adapter.

| Function | Returns / does |
| --- | --- |
| `anchor_version` | the current version as `name+build` |
| `anchor_release` | bump the build, build, upload; echo the new version |
| `anchor_patch` | ship a patch onto the live build from a list of commits |

`flutter-shorebird` wraps what this workspace does today. It is the adapter for
both consumers: Foxy Junior does not have Shorebird yet and adds it as part of
adoption, so its `tool/release.sh` (a hand port of these scripts with OTA cut
out) is replaced rather than wrapped. `generic-semver` reads and writes a
`VERSION` file and shells out to project-supplied build commands, so a project on
another stack has a working starting point.

## Plugin surface

- **`/release`** — `add`, `status`, `preflight`, `cut`. The workflow it drives is
  the one in `releases/RELEASE_PROCESS.md`, unchanged.
- **`/app-live`** — mark a build actually live: update the note's status, push
  the tag, merge it into the `mirror` branch, run `post_release`.
- **`/workspace-doctor`** — extracted from `scripts/workspace-doctor.sh`, which
  already exists. It reports; it does not fix. Checks carried over:
  `AGENTS.md` not a symlink, agent config gitignored, git hooks not installed,
  rules file past its size budget, each `.env` against its own `.example`, a
  repo with a test suite and no CI workflow, merged branches left behind,
  worktrees whose branch is already merged, stray `*.md` at the root beyond the
  three rules files, and — multi-repo only — relay stubs missing, drifted, or
  unregistered in a repo's `settings.json`, and worktrees that predate the stub.
- **`guard-release`** — a PreToolUse hook turning a release cut or a store
  submission into a confirmation prompt. It asks, never blocks.
- **`guard-pr-contract`** — a PreToolUse hook on `gh pr create` that runs the
  contract check when the diff touches a `contract_paths` entry and asks before
  opening a PR that changes a contract without its counterpart.
- **`doctor-on-start`** — a SessionStart hook that runs the doctor and prints
  only warnings and failures.
- **`workspace-guards.stub`** — multi-repo only. A byte-identical relay each
  product repo carries in `.claude/hooks/`, walking up from its git top-level
  (stripping `/.claude/worktrees/*`) to the workspace's hooks and printing the
  first decision. Needed because Claude Code loads hooks only from the directory
  a session is opened in.
- **Persona skills** — `product-analyst`, `business-analyst`,
  `market-researcher`, `product-owner`, `conversion-audit`. Method-only:
  each reads its workspace-specific knowledge from `docs/personas/` (stubs
  scaffolded by `init` from `templates/personas/`, each carrying an
  `ADOPT-ME` marker). A skill that finds its file missing or still marked
  runs adoption first — explore the workspace, interview the owner, fill
  the file — then does the asked job. They never edit product code, and
  they hand off to each other by name: analyst measures, owner decides,
  audit diagnoses money, BA writes requirements, researcher looks outward.
  `skill-coach` maintains the layer: observed failure → classify (stale
  knowledge / wrong method / unfollowed rule / not the skill) → smallest
  fix at the right layer (knowledge directly; method with approval;
  kit-owned method upstream) → verify → log in `docs/skill-lessons.md`.
- **`contract-reviewer`** — an agent template that reads the contract table and
  reviews a PR against it. Shipped as a template because the table is
  project-specific; `init` writes an empty table for it.
- **`pre-commit`** — blocks commits on a trunk branch.
- **`post-merge`** — reminds you to record an item when the trunk moves to a
  commit the inventory does not list.

## CLI

`npx agent-workspace-kit init`, run once at a workspace root:

1. Detects the shape: sibling `.git` directories mean multi-repo; one `.git` with
   role directories means monorepo. Asks to confirm.
2. Asks the trunk and role of each repo or directory.
3. Picks an adapter, defaulting from what it detects (a `pubspec.yaml` implies
   `flutter-shorebird`). If Shorebird is not initialised, says so and points at
   the runbook; it does not run `shorebird init` itself.
4. Writes `workspace.yml`, the `releases/` skeleton (`UNRELEASED.md`,
   `RELEASE_PROCESS.md` with a "Release obligations" section, note templates),
   and a rules-file skeleton carrying the conventions and an empty contract
   table.
5. Writes `.claude/settings.json` (hooks registered, `worktree.bgIsolation:
   none`), creates the `AGENTS.md` → `CLAUDE.md` and `.agents/skills` →
   `.claude/skills` symlinks, installs the git hooks (through husky when
   present), and in multi-repo copies the relay stub into each repo.
6. Prints what it did and what the user must fill in by hand.

`npx agent-workspace-kit doctor` runs the same checks as the skill, for use
outside a Claude session. `npx agent-workspace-kit check` runs shellcheck, the
test suite and the doctor, the same gate `scripts/check.sh` is today.

Re-running `init` never overwrites an existing `workspace.yml`; it reports the
difference instead.

## Verification for v1

No CI on the kit repo, by decision. Instead, in order:

1. **`check`** — `shellcheck` over `lib/`, `adapters/`, `hooks/`, `git-hooks/`
   and `bin/`, plus the test suite extracted from `scripts/test/` (24 cases
   today), run locally before each release of the kit.
2. **Every command supports `--dry-run`**, printing what it would write and run.
3. **Parity with VieSpeak.** The kit runs against this workspace in parallel with
   the existing `scripts/`, on the same inputs, until an `add`, a `status`, a
   `cut --dry-run` and the doctor (Hooks section excepted, since the kit wires
   hooks differently by design) produce byte-identical output, and `preflight`
   reaches the same verdict on every check. Only then does VieSpeak switch and
   delete its copy.
4. **Clean adoption by Foxy Junior.** Only after step 3, so a failure there is
   the monorepo shape and not the kit. `init` runs on a fresh worktree of
   `tai9/foxy-junior`; the doctor must reach zero failures; a `status` and a
   `preflight` must run; a store cut is rehearsed with `--dry-run`. Adding
   Shorebird to Foxy Junior is part of this step and gets its own issue there.

## Migration

1. Build the kit and prove parity as above.
2. VieSpeak's `scripts/` shrinks to a `workspace.yml` plus any project-specific
   post-release command (`lib/app-versions.mjs` stays; it is the Supabase gate).
3. The generic half of `releases/RELEASE_PROCESS.md` moves into the kit's docs;
   what stays here is the VieSpeak-specific cross-repo coordination.
4. Foxy Junior adopts: `workspace.yml`, `releases/`, hooks, rules-file split,
   Shorebird. Its `tool/release.sh` is deleted once the kit's `preflight` covers
   its `.env.store` checks, which move to a `preflight.extra` script.

## Risks

- **The kit becomes a second thing to maintain.** Mitigated by keeping v1 small
  and refusing every generalisation not needed by one of the two consumers.
- **Parity is easy to claim and hard to hold.** The byte-identical gate above is
  the whole defence; without it this is a rewrite wearing a refactor's clothes.
- **Two shapes tempt a third.** The shape table above is the whole surface of
  the difference. Any new row must be justified by one of the two consumers.
- **A public repo invites questions.** Accepted deliberately: the README must say
  plainly that v1 targets a mobile app plus backend, in either shape, and
  nothing else.
