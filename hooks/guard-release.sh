#!/usr/bin/env bash
# PreToolUse guard for the "never cut a release unprompted" rule in CLAUDE.md.
#
# The rule is written down, but nothing enforced it: a status question read as an
# instruction was one tool call away from tagging a build and uploading it. This
# turns that call into a confirmation prompt. It never blocks — the user can
# still say yes in the same breath — it only removes "silently" as an option.
#
# Uses node (the kit's only hard dependency) to parse JSON, not python3 — a
# machine without python3 must not let this guard silently never fire.
set -euo pipefail

payload=$(cat)
cmd=$(printf '%s' "$payload" | node -e '
  let d = require("fs").readFileSync(0, "utf8");
  try {
    const o = JSON.parse(d);
    process.stdout.write((o.tool_input && o.tool_input.command) || "");
  } catch (e) {}
' 2>/dev/null || true)

reason=""
case "$cmd" in
  *release-cut*|*"release cut"*)
    reason="release cut tags a build, writes the release note and can upload to the stores. The workspace rule requires an explicit go-ahead in the same turn; a status question is not one." ;;
  *--submit-for-review*)
    reason="--submit-for-review queues an Apple review or promotes a Play track to production. That step is not reversible; confirm before it runs." ;;
esac

if [ -n "$reason" ]; then
  node -e '
    const reason = process.argv[1];
    console.log(JSON.stringify({hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: reason,
    }}));
  ' -- "$reason"
fi
exit 0
