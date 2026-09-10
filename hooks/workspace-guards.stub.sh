#!/usr/bin/env sh
# Canonical copy of <repo>/.claude/hooks/workspace-guards.sh. Byte-copied into
# the workspace root and, in a multi-repo workspace, into every guarded repo;
# the doctor fails when a copy drifts from this file.
#
# Claude Code loads hooks only from the directory a session is opened in, and
# $CLAUDE_PROJECT_DIR is the worktree inside one, so a settings.json path into
# node_modules does not survive a worktree. Walking up from the git toplevel
# finds the kit in both cases; with no kit above, this exits quietly.
#
#   workspace-guards.sh                PreToolUse: relay stdin to the guards
#   workspace-guards.sh session-start  SessionStart: run the doctor
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
case "$top" in *"/.claude/worktrees/"*) top="${top%%/.claude/worktrees/*}";; esac
kit=""
for c in "$top/node_modules/agent-workspace-kit" "$(dirname "$top")/node_modules/agent-workspace-kit"; do
  [ -d "$c/hooks" ] && { kit="$c"; break; }
done
[ -n "$kit" ] || exit 0
if [ "${1:-}" = "session-start" ]; then exec "$kit/hooks/doctor-on-start.sh"; fi
payload=$(cat)
for guard in guard-release.sh guard-pr-contract.sh; do
  [ -x "$kit/hooks/$guard" ] || continue
  out=$(printf '%s' "$payload" | "$kit/hooks/$guard" 2>/dev/null)
  if [ -n "$out" ]; then printf '%s\n' "$out"; exit 0; fi
done
exit 0
