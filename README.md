# agent-workspace-kit

The agent workflow VieSpeak runs on, extracted so other projects can adopt it:
worktree discipline, one rules file, guard hooks, a drift doctor, and a
release layer with an unreleased inventory, `released/` tags and OTA patches.

Ships as a Claude Code plugin and a CLI from one shared core.

**v1 targets one thing:** a mobile app plus a backend, in either of two shapes —
sibling repos under a workspace root (multi-repo) or one repo with role
directories (monorepo). Nothing else.

Design: [`docs/design.md`](docs/design.md). Status: design approved, not yet
implemented. First consumers: VieSpeak (multi-repo) and Foxy Junior (monorepo).
