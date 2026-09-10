#!/usr/bin/env bash
# Locates the workspace and exposes workspace.yml as cfg/cfg_list/cfg_keys.
# Sourced by lib/release-common.sh after lib/out.sh. One node call per process.
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Walk up from $WORKSPACE_ROOT (if set) or $PWD to the first workspace.yml. A
# worktree of the workspace repo (…/.claude/worktrees/<x>) resolves to the real
# checkout, where the product repos actually are.
find_workspace_root() {
  local d="${WORKSPACE_ROOT:-$PWD}"
  case "$d" in *"/.claude/worktrees/"*) d="${d%%/.claude/worktrees/*}";; esac
  while [ "$d" != "/" ]; do
    [ -f "$d/workspace.yml" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}
WORKSPACE_ROOT="$(find_workspace_root)" || die "no workspace.yml found above ${WORKSPACE_ROOT:-$PWD} (run 'agent-workspace-kit init' at the workspace root, or set WORKSPACE_ROOT)"
WORKSPACE_YML="$WORKSPACE_ROOT/workspace.yml"
CFG_FLAT="$(node "$KIT_ROOT/bin/config.mjs" "$WORKSPACE_YML")" || die "could not read $WORKSPACE_YML"

_cfg_escape() { printf '%s' "$1" | sed 's/[.[\*^$#]/\\&/g'; }
cfg()      { printf '%s\n' "$CFG_FLAT" | sed -n "s/^$(_cfg_escape "$1")=//p" | head -n1; }
cfg_default() { local v; v="$(cfg "$1")"; [ -n "$v" ] && printf '%s' "$v" || printf '%s' "$2"; }
cfg_list() {
  local n i=0; n="$(cfg "$1.#")"; [ -n "$n" ] || return 0
  while [ "$i" -lt "$n" ]; do cfg "$1.$i"; i=$((i+1)); done
}
cfg_keys() { printf '%s\n' "$CFG_FLAT" | grep "^$(_cfg_escape "$1")\." | sed "s/^$(_cfg_escape "$1")\.//; s/[.=].*//" | awk '!s[$0]++'; }
