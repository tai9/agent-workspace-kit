---
name: release
description: Drive the workspace's release workflow — record merged items, show the unreleased inventory, run pre-flight, and cut a release or OTA patch. Use when the user wants to add a finished item to the release, check what's unreleased, or ship a patch/release. Thin wrapper over `agent-workspace-kit release …`.
---

# Release workflow

Orchestrates the kit's release commands. The full process lives in
`releases/RELEASE_PROCESS.md` at the workspace root; ship mechanics for the
configured adapter live wherever that adapter's own docs point. **Do not
reimplement classification or ship logic here — always call the CLI.** Run
everything from the workspace root (the directory holding `workspace.yml`,
`releases/`, and the anchor/service repos or role directories it names — see
`workspace.yml` for which repo is "the anchor repo" and which is "the service
repo").

Parse the user's intent into one of: `add`, `status`, `preflight`, `cut`.

## add — record a merged item (run after a squash-merge into the anchor trunk)

1. Identify the squashed commit. Default is the anchor trunk HEAD; if the
   user names a commit/branch, resolve it.
2. If the feature had a paired change in the service repo (or another repo
   named in `workspace.yml`), get that commit.
3. Run: `agent-workspace-kit release add [<commit>] [--paired [<repo>:]<commit>]`
   (`--be <commit>` also works, as a shorthand for `--paired` against the
   workspace's single service repo — kept for backward compatibility).
4. Relay the recorded row (channel, type, summary, coupling). If the command
   warned about a contract-path consumer file and the user didn't pass
   `--paired`/`--be`, ask whether there's a paired change and re-run with it
   if so.

## status — show the unreleased inventory

Read and render `releases/UNRELEASED.md` (what `agent-workspace-kit release
status` prints), grouped by channel (🟢 OTA / 🔴 Store), highlighting coupled
items. This is the menu the user picks from at cut time.

## preflight — gate before shipping

Run `agent-workspace-kit release preflight <env> --mode <patch|release>` and
summarize pass/fail. Do not proceed to a cut if it fails; surface the ✗ items.

## cut — ship a patch or release

1. Show `status` and ask which items to ship and whether it's a **patch** (OTA
   only) or **release** (store build).
2. Run `preflight` for the target env/mode first.
3. **If any picked/at-risk item is coupled**, walk the deploy-ordering rule:
   confirm the required service-repo commit is the *deployed* one on the
   target env before shipping the app. (Preflight checks the service backend's
   liveness, not the specific commit.)
4. Run the cut:
   - Patch: `agent-workspace-kit release cut patch <env> <ios|android> --items "<n ...>"`
     (run once per platform).
   - Release: `agent-workspace-kit release cut release <env> <ios|android|both> [--distribute] [--at <commit>]`
   - Offer `--dry-run` first when the user is unsure — it prints the resolved
     plan (base, tag, commits, target files) and changes nothing.
5. After a successful cut, relay the final checklist the command prints: store
   upload and `git push --tags` for the new `released/<version>` tag.
6. Remind that the go-live step happens **only once the build is live on the
   stores** (approved/rolled out) — never at submit time. It is the
   `app-live` skill (wrapping `agent-workspace-kit live <version>`): note
   status → live, tag pushed, the `released/<version>` **tag** merged into
   the mirror branch, and the project's own `post_release` commands run.
   Nothing else writes to the mirror branch.

## Guardrails

- A patch refuses 🔴 Store items by design — if the user wants those shipped,
  it must be a release.
- Never edit `UNRELEASED.md` or the version notes by hand; the commands own
  them.
- The commands ship from a throwaway worktree and clean it up; don't run the
  release adapter against the user's working tree.
