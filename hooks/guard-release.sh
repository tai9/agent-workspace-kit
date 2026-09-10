#!/usr/bin/env bash
# PreToolUse guard for the "never cut a release unprompted" rule in CLAUDE.md.
#
# The rule is written down, but nothing enforced it: a status question read as an
# instruction was one tool call away from tagging a build and uploading it. This
# turns that call into a confirmation prompt. It never blocks — the user can
# still say yes in the same breath — it only removes "silently" as an option.
set -euo pipefail

payload=$(cat)
cmd=$(printf '%s' "$payload" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null || true)

reason=""
case "$cmd" in
  *release-cut*|*"release cut"*)
    reason="release cut tags a build, writes the release note and can upload to the stores. The workspace rule requires an explicit go-ahead in the same turn; a status question is not one." ;;
  *--submit-for-review*)
    reason="--submit-for-review queues an Apple review or promotes a Play track to production. That step is not reversible; confirm before it runs." ;;
esac

if [ -n "$reason" ]; then
  python3 - "$reason" <<'PY'
import json, sys
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": sys.argv[1],
}}))
PY
fi
exit 0
