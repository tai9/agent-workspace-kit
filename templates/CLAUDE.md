# {{NAME}} — Workspace Root

This directory is a workspace this kit runs. Fill in what the app does and how
its repos relate here; the conventions below are the ones every session in
this workspace should follow.

## Conventions

- **All work goes through a git worktree, branched from the repo's trunk.**
  Never edit directly on the checked-out branch — it can be switched out from
  under you by another session. Create the worktree off the trunk, do the work
  there, merge/PR back into that same trunk, then remove it.
- **The trunk is what `workspace.yml` says it is** (`trunk:` at the root, or
  per-repo under `repos.<name>.trunk`). Branch off it, PR into it.
- **One rules file per repo, the other symlinked to it.** Whichever of
  `CLAUDE.md` / `AGENTS.md` came first stays the real file; the other is a
  symlink to it, so both readers always see the same text.
- **Rules stay separate from reference material.** This file holds rules an
  agent must follow, not a walkthrough of the codebase or a design doc — link
  out to those instead of inlining them here.
- **Agent configuration is under version control.** `.claude/` (hooks, skills,
  settings) is committed, not gitignored — it has to survive a fresh clone.
- **Never cut a release or submit something for review without an explicit
  go-ahead in the same turn.** A status or check question — "what's pending",
  "is this ready?" — is read-only: answer it and stop. Only proceed to an
  actual cut or submission after an imperative in that turn.
- **Hooks back the rule above.** `.claude/hooks/workspace-guards.sh` relays a
  `PreToolUse` check that turns a release-cut invocation into a confirmation
  prompt, and a `SessionStart` check that runs the drift doctor, silent unless
  something needs attention. A session opened inside a product repo carries
  its own byte copy of the stub so the guards still load there.
- **Releasing has its own obligations.** See the "Release obligations"
  section of [`releases/RELEASE_PROCESS.md`](releases/RELEASE_PROCESS.md) —
  what every release owes before it's actually done.

## Cross-repo contracts

Fill this in as contracts are added to `workspace.yml`'s `contracts:` list —
see [`docs/cross-repo-contracts.md`](docs/cross-repo-contracts.md) for the
rules behind each row.

| Contract | Owner | Consumers | Closed set? |
| --- | --- | --- | --- |
