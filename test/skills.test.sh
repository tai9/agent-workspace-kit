#!/usr/bin/env bash
# Guards skills/, agents/ and README.md against describing a subcommand the
# dispatcher (bin/agent-workspace-kit.mjs) does not actually route. Static —
# it only checks subcommand names against the dispatcher's own table, it
# never runs anything.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DISPATCH="$KIT/bin/agent-workspace-kit.mjs"
[ -f "$DISPATCH" ] || { echo "missing $DISPATCH"; exit 1; }

# Top-level subcommands the dispatcher routes (mirrors its `table` plus the
# special-cased `release`).
TOP="init doctor check live contract-check install-git-hooks release"
# release's own subcommands (mirrors the `release` branch's allow-list).
RELEASE_SUB="add status preflight cut"

is_in() { # <needle> <haystack-space-list>
  local n="$1" h="$2" w
  for w in $h; do [ "$w" = "$n" ] && return 0; done
  return 1
}

FILES=()
while IFS= read -r -d '' f; do FILES+=("$f"); done < <(find "$KIT/skills" "$KIT/agents" -type f -print0 2>/dev/null)
[ -f "$KIT/README.md" ] && FILES+=("$KIT/README.md")

echo "checking ${#FILES[@]} file(s) for agent-workspace-kit invocations"

for f in "${FILES[@]}"; do
  # Every `agent-workspace-kit <word>` occurrence, word = [a-zA-Z-]+.
  while IFS= read -r sub; do
    [ -n "$sub" ] || continue
    if is_in "$sub" "$TOP"; then
      t_ok "$(basename "$f"): agent-workspace-kit $sub"
    else
      t_bad "$(basename "$f"): agent-workspace-kit $sub" "a top-level subcommand in: $TOP" "$sub"
    fi
  done < <(grep -oE 'agent-workspace-kit +[a-zA-Z-]+' "$f" | awk '{print $2}' | sort -u)

  # Every `agent-workspace-kit release <word>` occurrence.
  while IFS= read -r sub; do
    [ -n "$sub" ] || continue
    if is_in "$sub" "$RELEASE_SUB"; then
      t_ok "$(basename "$f"): agent-workspace-kit release $sub"
    else
      t_bad "$(basename "$f"): agent-workspace-kit release $sub" "one of: $RELEASE_SUB" "$sub"
    fi
  done < <(grep -oE 'agent-workspace-kit +release +[a-zA-Z-]+' "$f" | awk '{print $3}' | sort -u)
done

finish
