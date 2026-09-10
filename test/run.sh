#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$here"/*.test.sh; do
  printf '\n\033[1m%s\033[0m\n' "$(basename "$t")"
  out="$(bash "$t" 2>&1)" || rc=1
  printf '%s\n' "$out" | grep -E 'FAIL|expected:|got:' || true
  printf '%s\n' "$out" | tail -1
done
exit "$rc"
