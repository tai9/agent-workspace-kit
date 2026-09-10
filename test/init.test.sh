#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
CLI="node $KIT/bin/agent-workspace-kit.mjs"

echo "multi-repo init"
mkdir -p "$TMP/m"; git_init "$TMP/m/my-app"; git_init "$TMP/m/my-be"
printf 'name: x\nversion: 1.0.0+1\n' > "$TMP/m/my-app/pubspec.yaml"; git -C "$TMP/m/my-app" branch develop
printf '{}' > "$TMP/m/my-be/package.json"; touch "$TMP/m/my-be/nest-cli.json"
mkdir -p "$TMP/m/node_modules"; ln -s "$KIT" "$TMP/m/node_modules/agent-workspace-kit"
out="$(cd "$TMP/m" && $CLI init --yes 2>&1)"; rc=$?
is "init exits 0" "0" "$rc"
grep -q '^shape: multi-repo' "$TMP/m/workspace.yml" && t_ok "detects multi-repo" || t_bad "shape" "multi-repo" "$(cat "$TMP/m/workspace.yml")"
grep -q 'role: release-anchor' "$TMP/m/workspace.yml" && t_ok "detects the anchor" || t_bad "anchor" "release-anchor" "?"
grep -q 'trunk: develop' "$TMP/m/workspace.yml" && t_ok "detects develop" || t_bad "trunk" "develop" "?"
[ -L "$TMP/m/AGENTS.md" ] && t_ok "AGENTS.md symlink" || t_bad "symlink" "link" "none"
[ -f "$TMP/m/my-app/.claude/hooks/workspace-guards.sh" ] && t_ok "stub in the anchor repo" || t_bad "stub" "file" "none"
cmp -s "$KIT/hooks/workspace-guards.stub.sh" "$TMP/m/my-be/.claude/hooks/workspace-guards.sh" && t_ok "stub is a byte copy" || t_bad "byte copy" "same" "differs"
grep -q 'workspace-guards.sh session-start' "$TMP/m/.claude/settings.json" && t_ok "settings registered" || t_bad "settings" "session-start" "?"
[ -f "$TMP/m/releases/UNRELEASED.md" ] && t_ok "inventory" || t_bad "inventory" "file" "none"
[ -x "$TMP/m/my-app/.git/hooks/post-merge" ] && t_ok "git hooks installed" || t_bad "git hooks" "post-merge" "none"
printf '%s' "$out" | grep -q 'Shorebird is not initialised' && t_ok "warns about shorebird" || t_bad "shorebird warn" "warn" "$out"
[ -f "$TMP/m/my-app/CLAUDE.md" ] && [ -L "$TMP/m/my-app/AGENTS.md" ] && t_ok "per-repo rules file in the anchor" || t_bad "per-repo rules" "CLAUDE.md + AGENTS.md symlink" "?"
[ -f "$TMP/m/my-be/CLAUDE.md" ] && [ -L "$TMP/m/my-be/AGENTS.md" ] && t_ok "per-repo rules file in the service repo" || t_bad "per-repo rules be" "CLAUDE.md + AGENTS.md symlink" "?"
[ -f "$TMP/m/docs/cross-repo-contracts.md" ] && t_ok "cross-repo-contracts.md copied into docs/" || t_bad "contracts doc" "file" "none"
out="$(cd "$TMP/m" && WORKSPACE_ROOT="$TMP/m" bash "$KIT/bin/doctor" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'FAIL' && t_bad "doctor has no FAIL after init" "0 fail" "$(printf '%s' "$out" | grep FAIL)" || t_ok "doctor has no FAIL after init"

echo "re-run"
before_ws="$(cat "$TMP/m/workspace.yml")"
before_settings_count="$(grep -c 'workspace-guards.sh' "$TMP/m/.claude/settings.json")"
out="$(cd "$TMP/m" && $CLI init --yes 2>&1)"
printf '%s' "$out" | grep -q 'workspace.yml exists' && t_ok "never overwrites workspace.yml" || t_bad "rerun" "exists" "$out"
[ "$before_ws" = "$(cat "$TMP/m/workspace.yml")" ] && t_ok "workspace.yml untouched on re-run" || t_bad "workspace.yml untouched" "$before_ws" "$(cat "$TMP/m/workspace.yml")"
after_settings_count="$(grep -c 'workspace-guards.sh' "$TMP/m/.claude/settings.json")"
[ "$before_settings_count" = "$after_settings_count" ] && t_ok "no duplicated hook entries on re-run" || t_bad "no dup hooks" "$before_settings_count" "$after_settings_count"

echo "monorepo init"
git_init "$TMP/o"; mkdir -p "$TMP/o/app" "$TMP/o/backend/prisma"; printf 'version: 1.0.0+6\n' > "$TMP/o/app/pubspec.yaml"; printf '{}' > "$TMP/o/backend/package.json"
mkdir -p "$TMP/o/.husky" "$TMP/o/node_modules"; ln -s "$KIT" "$TMP/o/node_modules/agent-workspace-kit"
out="$(cd "$TMP/o" && $CLI init --yes 2>&1)"
grep -q '^shape: monorepo' "$TMP/o/workspace.yml" && t_ok "detects monorepo" || t_bad "shape" "monorepo" "$(cat "$TMP/o/workspace.yml")"
grep -q 'anchor_file: app/pubspec.yaml' "$TMP/o/workspace.yml" && t_ok "anchor file under the subdir" || t_bad "anchor_file" "app/pubspec.yaml" "?"
[ -f "$TMP/o/app/.claude/hooks/workspace-guards.sh" ] && t_bad "no per-dir stubs in mono" "none" "file" || t_ok "no per-dir stubs in mono"
[ -f "$TMP/o/app/CLAUDE.md" ] && t_bad "no per-dir rules files in mono" "none" "file" || t_ok "no per-dir rules files in mono"
grep -q awk-pre-commit "$TMP/o/.husky/pre-commit" && t_ok "husky wired" || t_bad "husky" "awk-pre-commit" "?"
out2="$(cd "$TMP/o" && WORKSPACE_ROOT="$TMP/o" bash "$KIT/bin/doctor" 2>&1 | strip_ansi)"
printf '%s' "$out2" | grep -q 'FAIL' && t_bad "doctor has no FAIL after monorepo init" "0 fail" "$(printf '%s' "$out2" | grep FAIL)" || t_ok "doctor has no FAIL after monorepo init"

echo "dry run"
mkdir -p "$TMP/d"; git_init "$TMP/d/a"; printf 'version: 1.0.0+1\n' > "$TMP/d/a/pubspec.yaml"
(cd "$TMP/d" && $CLI init --yes --dry-run >/dev/null 2>&1)
[ -f "$TMP/d/workspace.yml" ] && t_bad "dry run writes nothing: workspace.yml" "none" "file" || t_ok "dry run writes nothing: workspace.yml"
[ -f "$TMP/d/CLAUDE.md" ] && t_bad "dry run writes nothing: CLAUDE.md" "none" "file" || t_ok "dry run writes nothing: CLAUDE.md"
[ -f "$TMP/d/releases/UNRELEASED.md" ] && t_bad "dry run writes nothing: UNRELEASED.md" "none" "file" || t_ok "dry run writes nothing: UNRELEASED.md"
[ -f "$TMP/d/a/.claude/hooks/workspace-guards.sh" ] && t_bad "dry run writes nothing: stub" "none" "file" || t_ok "dry run writes nothing: stub"
[ -f "$TMP/d/.claude/settings.json" ] && t_bad "dry run writes nothing: settings.json" "none" "file" || t_ok "dry run writes nothing: settings.json"
[ -x "$TMP/d/a/.git/hooks/post-merge" ] && t_bad "dry run writes nothing: git hooks" "none" "file" || t_ok "dry run writes nothing: git hooks"

echo "settings merge keeps unrelated content"
mkdir -p "$TMP/s"; git_init "$TMP/s/a"; printf 'version: 1.0.0+1\n' > "$TMP/s/a/pubspec.yaml"
mkdir -p "$TMP/s/.claude"; printf '{"env":{"FOO":"bar"},"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"echo hi"}]}]}}' > "$TMP/s/.claude/settings.json"
(cd "$TMP/s" && $CLI init --yes >/dev/null 2>&1)
node -e '
const j = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
if (j.env && j.env.FOO === "bar" && j.hooks.PreToolUse.some(e => e.matcher === "Edit")) process.exit(0);
process.exit(1);
' "$TMP/s/.claude/settings.json" && t_ok "settings merge keeps unrelated content" || t_bad "settings merge" "keeps env+Edit hook" "$(cat "$TMP/s/.claude/settings.json")"
grep -q 'workspace-guards.sh session-start' "$TMP/s/.claude/settings.json" && t_ok "settings merge gains the hook entries" || t_bad "settings merge hooks" "session-start" "$(cat "$TMP/s/.claude/settings.json")"

echo "root rules file already present is not overwritten"
mkdir -p "$TMP/r"; git_init "$TMP/r/a"; printf 'version: 1.0.0+1\n' > "$TMP/r/a/pubspec.yaml"
printf '# existing rules, hand written\n' > "$TMP/r/CLAUDE.md"
(cd "$TMP/r" && $CLI init --yes >/dev/null 2>&1)
[ "$(cat "$TMP/r/CLAUDE.md")" = "# existing rules, hand written" ] && t_ok "existing root CLAUDE.md left alone" || t_bad "root CLAUDE.md" "unchanged" "$(cat "$TMP/r/CLAUDE.md")"

echo "role fallback: neither anchor nor service"
mkdir -p "$TMP/x"; git_init "$TMP/x/my-app"; git_init "$TMP/x/my-be"; git_init "$TMP/x/my-docs"
printf 'name: x\nversion: 1.0.0+1\n' > "$TMP/x/my-app/pubspec.yaml"
printf '{}' > "$TMP/x/my-be/package.json"; touch "$TMP/x/my-be/nest-cli.json"
printf 'notes\n' > "$TMP/x/my-docs/README.md"
(cd "$TMP/x" && $CLI init --yes >/dev/null 2>&1)
grep -q '{ path: my-docs, trunk: .*, role: other' "$TMP/x/workspace.yml" && t_ok "unrecognised repo falls back to role: other" || t_bad "role fallback" "role: other" "$(cat "$TMP/x/workspace.yml")"

echo "dispatcher"
out="$($CLI 2>&1)"; rc=$?
is "no args exits 0" "0" "$rc"
printf '%s' "$out" | grep -q 'usage: agent-workspace-kit' && t_ok "no args prints usage" || t_bad "usage" "usage:" "$out"
out="$($CLI bogus 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && t_ok "unknown command exits non-zero" || t_bad "unknown command" "non-zero" "$rc"
printf '%s' "$out" | grep -q 'usage: agent-workspace-kit' && t_ok "unknown command prints usage" || t_bad "unknown usage" "usage:" "$out"
out="$(cd "$TMP/m" && WORKSPACE_ROOT="$TMP/m" $CLI install-git-hooks --dry-run 2>&1)"; rc=$?
is "install-git-hooks routes and exits 0" "0" "$rc"
printf '%s' "$out" | grep -qi 'pre-commit\|post-merge' && t_ok "install-git-hooks dispatch reaches the real script" || t_bad "install-git-hooks route" "pre-commit/post-merge" "$out"

finish
