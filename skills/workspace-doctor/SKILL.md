---
name: workspace-doctor
description: Check the workspace for drift that stays invisible until it bites — a rules file that has grown into an encyclopedia, agent config hidden by gitignore, a missing AGENTS.md symlink, hooks not installed, env keys absent from .env.example, branches and worktrees already merged, a trunk out of step with origin. Use when the user asks whether the workspace is clean or tidy, before starting a release, after merging a batch of PRs, or when they type /workspace-doctor.
---

# workspace-doctor

Run the checker and report what it found. It reports only; it never changes
anything.

```sh
agent-workspace-kit doctor
```

## Reading the output

Each line is `ok`, `warn` or `FAIL`. It exits non-zero when anything failed.

- **FAIL** is a rule that is currently broken: a repo whose `CLAUDE.md` and
  `AGENTS.md` are both real files and will drift, a `.gitignore` hiding all of
  `.claude`, a missing release guard, an env key nowhere in `.env.example`.
- **warn** is drift, not breakage: a rules file past 400 lines, a merged branch
  or worktree left behind, a trunk ahead of or behind origin.

## Reporting

Say what failed and what it costs, not just the count. Group by repo. For each
failure, name the fix in one line:

| Finding | Fix |
| --- | --- |
| Both rules files are real | Delete one, symlink it to the other |
| `.gitignore` hides `.claude` | Narrow it to `worktrees/` and `settings.local.json` |
| Rules file past 400 lines | Move the reference chapters into `docs/`, leave an index |
| Key missing from `.env.example` | Add the key with a placeholder and a one-line comment |
| Release guard not wired | Restore the `PreToolUse` hook in `.claude/settings.json` |
| Hook not installed | `agent-workspace-kit install-git-hooks` |

Do not fix anything unless the user asks. A warn on a worktree may belong to a
session that is still running — check before suggesting its removal.
