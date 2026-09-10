#!/usr/bin/env bash
# PreToolUse: when a PR is about to be opened, say whether the change touches a
# cross-repo contract and whether the other side has moved.
#
# This fires at the one moment the answer still changes what you do. It asks; it
# never blocks, and it stays silent for the great majority of PRs that touch no
# contract at all.
#
# Registered from each repo's .claude/settings.json (relayed there through
# workspace-guards.sh). The kit lives one directory up from this script; if
# bin/contract-check is not there and executable, this exits quietly.
#
# Uses node (the kit's only hard dependency) to parse JSON, not python3 — a
# machine without python3 must not let this guard silently never fire.
set -uo pipefail

payload=$(cat)
cmd=$(printf '%s' "$payload" | node -e '
  let d = require("fs").readFileSync(0, "utf8");
  try {
    const o = JSON.parse(d);
    process.stdout.write((o.tool_input && o.tool_input.command) || "");
  } catch (e) {}
' 2>/dev/null || true)
case "$cmd" in *"gh pr create"*) ;; *) exit 0;; esac

here="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$here" ] || exit 0
root="$here"
case "$root" in *"/.claude/worktrees/"*) root="${root%%/.claude/worktrees/*}";; esac
KIT="$(cd "$(dirname "$0")/.." && pwd)"
check="$KIT/bin/contract-check"
[ -x "$check" ] || exit 0

out="$(cd "$here" && bash "$check" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
printf '%s' "$out" | grep -q "touches it here" || exit 0

node -e '
  const report = process.argv[1].trim();
  console.log(JSON.stringify({hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason:
      "This branch touches a cross-repo contract. Half a contract ships " +
      "silently — the missing side degrades to a default rather than failing.\n\n" +
      report +
      "\n\nConfirm the other side is handled, or say it is one-sided by design.",
  }}));
' -- "$out"
exit 0
