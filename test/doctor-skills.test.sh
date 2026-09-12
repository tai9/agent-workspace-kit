#!/usr/bin/env bash
# The "Kit skills linked" doctor section: a kit skill missing from
# .claude/skills/ warns (unless declared unlinked_ok), a workspace-owned copy
# passes, and a dead symlink fails.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() { bash "$KIT/bin/doctor" 2>&1 | strip_ansi; }

make_multi "$TMP/s"; export WORKSPACE_ROOT="$TMP/s"

# Nothing linked at all: every kit skill warns, none fails.
out="$(run)"
printf '%s' "$out" | grep -q 'warn qa-engineer — kit skill not in .claude/skills/' \
  && t_ok "unlinked kit skill warns" || t_bad "unlinked warns" "warn qa-engineer" "$out"
printf '%s' "$out" | grep -q 'dead symlink' \
  && t_bad "no dead-symlink fail without links" "none" "dead symlink" || t_ok "no dead-symlink fail without links"

# A symlink to the kit skill passes as linked.
mkdir -p "$TMP/s/.claude/skills"
ln -s "$KIT/skills/product-analyst" "$TMP/s/.claude/skills/product-analyst"
# A real directory under a kit skill's name is a workspace-owned fork.
mkdir -p "$TMP/s/.claude/skills/market-researcher"
out="$(run)"
printf '%s' "$out" | grep -q 'ok   product-analyst — linked' \
  && t_ok "symlinked skill passes" || t_bad "linked" "ok product-analyst — linked" "$out"
printf '%s' "$out" | grep -q 'ok   market-researcher — workspace owns its own copy' \
  && t_ok "owned copy passes" || t_bad "owned copy" "workspace owns its own copy" "$out"

# Declaring a skill unlinked_ok silences its warn (list form).
printf 'skills:\n  unlinked_ok:\n    - qa-engineer\n' >> "$TMP/s/workspace.yml"
out="$(run)"
printf '%s' "$out" | grep -q 'ok   qa-engineer — unlinked on purpose' \
  && t_ok "unlinked_ok list silences the warn" || t_bad "unlinked_ok" "unlinked on purpose" "$out"

# A dead symlink is a FAIL, not a warn.
ln -s "$KIT/skills/no-such-skill" "$TMP/s/.claude/skills/ghost"
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL ghost — dead symlink in .claude/skills/' \
  && t_ok "dead symlink fails" || t_bad "dead symlink" "FAIL ghost — dead symlink" "$out"

finish
