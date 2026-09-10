#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
run() { bash "$KIT/bin/doctor" 2>&1 | strip_ansi; }
echo "multi-repo"
make_multi "$TMP/m"; export WORKSPACE_ROOT="$TMP/m"
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL my-app — no CLAUDE.md and no AGENTS.md' && t_ok "missing rules file fails" || t_bad "rules" "FAIL" "$out"
printf '%s' "$out" | grep -q 'FAIL my-app — no .claude/hooks/workspace-guards.sh' && t_ok "missing stub fails" || t_bad "stub" "FAIL" "$out"
printf '%s' "$out" | grep -q 'FAIL release guard not wired' && t_ok "root guard fails" || t_bad "root guard" "FAIL" "$out"
for r in my-app my-be; do
  printf '# rules\n' > "$TMP/m/$r/CLAUDE.md"; ln -s CLAUDE.md "$TMP/m/$r/AGENTS.md"
  mkdir -p "$TMP/m/$r/.claude/hooks"; cp "$KIT/hooks/workspace-guards.stub.sh" "$TMP/m/$r/.claude/hooks/workspace-guards.sh"
  printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/workspace-guards.sh"}]}]}}' > "$TMP/m/$r/.claude/settings.json"
done
mkdir -p "$TMP/m/.claude"; cp "$TMP/m/my-app/.claude/settings.json" "$TMP/m/.claude/settings.json"
out="$(run)"; rc=$?
is "clean multi exits 0" "0" "$rc"
printf '%s' "$out" | grep -q 'ok   my-app — workspace guards stub in place and registered' && t_ok "stub ok" || t_bad "stub ok" "ok" "$out"
printf '%s' "$out" | grep -q 'ok   my-app — one rules file, 1 lines, the other symlinked' && t_ok "rules ok" || t_bad "rules ok" "ok" "$out"
echo drift >> "$TMP/m/my-be/.claude/hooks/workspace-guards.sh"
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL my-be — workspace-guards.sh differs from' && t_ok "drifted stub fails" || t_bad "drift" "FAIL" "$out"
echo "monorepo"
make_mono "$TMP/o"; export WORKSPACE_ROOT="$TMP/o"
out="$(run)"
printf '%s' "$out" | grep -q 'not cloned' && t_bad "mono never says not cloned" "none" "not cloned" || t_ok "mono never says not cloned"
printf '%s' "$out" | grep -q 'FAIL Demo — no CLAUDE.md' && t_ok "checks the root once" || t_bad "root once" "FAIL Demo" "$out"
printf '%s' "$out" | grep -q 'workspace-guards.sh;' && t_bad "no stub check in mono" "none" "stub" || t_ok "no stub check in mono"
printf '%s' "$out" | grep -q 'loose .md' && t_bad "no root-docs check in mono" "none" "loose" || t_ok "no root-docs check in mono"
finish
