#!/usr/bin/env bash
# SessionStart: surface workspace drift without burning a turn on it.
#
# Prints nothing when the workspace is clean — a hook that speaks every session
# is a hook people learn to skip. Only failures are reported, and only as a
# one-line count plus the failing lines, never the whole report.
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$("$KIT/bin/doctor" 2>/dev/null)" && exit 0
fails="$(printf '%s\n' "$out" | grep -a "FAIL" | sed 's/\x1b\[[0-9;]*m//g')"
[ -z "$fails" ] && exit 0
printf 'workspace-doctor found drift:\n%s\nRun bin/doctor for the full report.\n' "$fails"
exit 0
