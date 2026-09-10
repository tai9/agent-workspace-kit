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

echo "individual FAIL conditions"

# both CLAUDE.md and AGENTS.md real files (neither symlinked)
make_multi "$TMP/f-both-real"; export WORKSPACE_ROOT="$TMP/f-both-real"
printf '# a\n' > "$TMP/f-both-real/my-app/CLAUDE.md"
printf '# b\n' > "$TMP/f-both-real/my-app/AGENTS.md"
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL my-app — CLAUDE.md and AGENTS.md are both real files; they will drift apart' \
  && t_ok "both rules files real fails" || t_bad "both real" "FAIL my-app — CLAUDE.md and AGENTS.md are both real files; they will drift apart" "$out"

# test files, no CI workflow
make_multi "$TMP/f-ci"; export WORKSPACE_ROOT="$TMP/f-ci"
mkdir -p "$TMP/f-ci/my-be/test"; printf 'x' > "$TMP/f-ci/my-be/test/foo_test.dart"
git -C "$TMP/f-ci/my-be" add -A; git -C "$TMP/f-ci/my-be" commit -qm tests
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL my-be — 1 test files and no workflow running them' \
  && t_ok "test files with no workflow fails" || t_bad "ci" "FAIL my-be — 1 test files and no workflow running them" "$out"

# .gitignore hides all of .claude
make_multi "$TMP/f-gitignore"; export WORKSPACE_ROOT="$TMP/f-gitignore"
printf '.claude\n' > "$TMP/f-gitignore/my-be/.gitignore"
git -C "$TMP/f-gitignore/my-be" add -A; git -C "$TMP/f-gitignore/my-be" commit -qm gitignore
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL my-be — .gitignore hides all of .claude; skills and agents die with the clone' \
  && t_ok "gitignored .claude fails" || t_bad "gitignore" "FAIL my-be — .gitignore hides all of .claude; skills and agents die with the clone" "$out"

# env key present in a file, absent from its example
make_multi "$TMP/f-env"; export WORKSPACE_ROOT="$TMP/f-env"
printf 'FOO=\n' > "$TMP/f-env/my-be/.env.example"
printf 'FOO=1\nBAR=2\n' > "$TMP/f-env/my-be/.env"
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL my-be — undocumented:.env.example:BAR' \
  && t_ok "undocumented env key fails" || t_bad "env undocumented" "FAIL my-be — undocumented:.env.example:BAR" "$out"

# relay stub present, matches, but not registered in that repo's settings
make_multi "$TMP/f-unreg"; export WORKSPACE_ROOT="$TMP/f-unreg"
for r in my-app my-be; do
  printf '# rules\n' > "$TMP/f-unreg/$r/CLAUDE.md"; ln -s CLAUDE.md "$TMP/f-unreg/$r/AGENTS.md"
  mkdir -p "$TMP/f-unreg/$r/.claude/hooks"; cp "$KIT/hooks/workspace-guards.stub.sh" "$TMP/f-unreg/$r/.claude/hooks/workspace-guards.sh"
done
printf '{}' > "$TMP/f-unreg/my-app/.claude/settings.json"
printf '{"x":"workspace-guards.sh"}' > "$TMP/f-unreg/my-be/.claude/settings.json"
mkdir -p "$TMP/f-unreg/.claude"; cp "$TMP/f-unreg/my-be/.claude/settings.json" "$TMP/f-unreg/.claude/settings.json"
out="$(run)"
printf '%s' "$out" | grep -q 'FAIL my-app — workspace-guards.sh present but not registered in .claude/settings.json' \
  && t_ok "unregistered stub fails" || t_bad "unregistered stub" "FAIL my-app — workspace-guards.sh present but not registered in .claude/settings.json" "$out"

echo "individual warn conditions"

# rules file past the size budget
make_multi "$TMP/f-budget"; export WORKSPACE_ROOT="$TMP/f-budget"
for i in $(seq 1 405); do echo "line $i" >> "$TMP/f-budget/my-app/CLAUDE.md"; done
ln -s CLAUDE.md "$TMP/f-budget/my-app/AGENTS.md"
out="$(run)"
printf '%s' "$out" | grep -q 'warn my-app — rules file is 405 lines; past 400 it is carrying reference material' \
  && t_ok "rules file over budget warns" || t_bad "budget" "warn my-app — rules file is 405 lines; past 400 it is carrying reference material" "$out"

# a local branch whose content is already in the trunk
make_multi "$TMP/f-stale"; export WORKSPACE_ROOT="$TMP/f-stale"
git clone -q "$TMP/f-stale/my-app" "$TMP/f-stale-origin" --bare
git -C "$TMP/f-stale/my-app" remote add origin "$TMP/f-stale-origin"
git -C "$TMP/f-stale/my-app" fetch -q origin
git -C "$TMP/f-stale/my-app" branch done-feature develop
out="$(run)"
printf '%s' "$out" | grep -q 'warn my-app — 1 local branch(es) whose content is already in develop' \
  && t_ok "merged branch warns" || t_bad "stale branch" "warn my-app — 1 local branch(es) whose content is already in develop" "$out"

# extra worktree left checked out
make_multi "$TMP/f-wt"; export WORKSPACE_ROOT="$TMP/f-wt"
git -C "$TMP/f-wt/my-app" worktree add -q -b extra-wt "$TMP/f-wt-extra"
out="$(run)"
printf '%s' "$out" | grep -q 'warn my-app — 1 extra worktree(s) still checked out' \
  && t_ok "extra worktree warns" || t_bad "extra worktree" "warn my-app — 1 extra worktree(s) still checked out" "$out"

# trunk ahead of its remote
make_multi "$TMP/f-ahead"; export WORKSPACE_ROOT="$TMP/f-ahead"
git clone -q "$TMP/f-ahead/my-app" "$TMP/f-ahead-origin" --bare
git -C "$TMP/f-ahead/my-app" remote add origin "$TMP/f-ahead-origin"
git -C "$TMP/f-ahead/my-app" fetch -q origin
git -C "$TMP/f-ahead/my-app" checkout -q develop
git -C "$TMP/f-ahead/my-app" branch --set-upstream-to=origin/develop develop -q
commit_file "$TMP/f-ahead/my-app" f.txt ahead >/dev/null
out="$(run)"
printf '%s' "$out" | grep -q 'warn my-app — develop\.\.\.origin/develop \[ahead 1\]' \
  && t_ok "trunk ahead of remote warns" || t_bad "ahead" "warn my-app — develop...origin/develop [ahead 1]" "$out"

# trunk behind its remote
make_multi "$TMP/f-behind"; export WORKSPACE_ROOT="$TMP/f-behind"
git clone -q "$TMP/f-behind/my-app" "$TMP/f-behind-origin" --bare
git -C "$TMP/f-behind/my-app" remote add origin "$TMP/f-behind-origin"
git -C "$TMP/f-behind/my-app" fetch -q origin
git -C "$TMP/f-behind/my-app" checkout -q develop
git -C "$TMP/f-behind/my-app" branch --set-upstream-to=origin/develop develop -q
git clone -q "$TMP/f-behind-origin" "$TMP/f-behind-other"
git -C "$TMP/f-behind-other" checkout -q develop >/dev/null 2>&1
commit_file "$TMP/f-behind-other" g.txt newer >/dev/null
git -C "$TMP/f-behind-other" push -q origin develop
git -C "$TMP/f-behind/my-app" fetch -q origin
out="$(run)"
printf '%s' "$out" | grep -q 'warn my-app — develop\.\.\.origin/develop \[behind 1\]' \
  && t_ok "trunk behind remote warns" || t_bad "behind" "warn my-app — develop...origin/develop [behind 1]" "$out"

# loose documents at the workspace root
make_multi "$TMP/f-loose"; export WORKSPACE_ROOT="$TMP/f-loose"
printf 'old spec\n' > "$TMP/f-loose/OLD_SPEC.md"
out="$(run)"
printf '%s' "$out" | grep -q 'warn 1 loose .md file(s) at the workspace root — move them under docs/' \
  && t_ok "loose root document warns" || t_bad "loose docs" "warn 1 loose .md file(s) at the workspace root — move them under docs/" "$out"

echo "behaviours"

# guards: false excludes a repo from the stub check entirely
make_multi "$TMP/f-guards"; export WORKSPACE_ROOT="$TMP/f-guards"
sed -i.bak 's/backend: { path: my-be, trunk: main, role: service }/backend: { path: my-be, trunk: main, role: service, guards: false }/' "$TMP/f-guards/workspace.yml"
printf '# rules\n' > "$TMP/f-guards/my-app/CLAUDE.md"; ln -s CLAUDE.md "$TMP/f-guards/my-app/AGENTS.md"
mkdir -p "$TMP/f-guards/my-app/.claude/hooks"; cp "$KIT/hooks/workspace-guards.stub.sh" "$TMP/f-guards/my-app/.claude/hooks/workspace-guards.sh"
printf '{"x":"workspace-guards.sh"}' > "$TMP/f-guards/my-app/.claude/settings.json"
mkdir -p "$TMP/f-guards/.claude"; cp "$TMP/f-guards/my-app/.claude/settings.json" "$TMP/f-guards/.claude/settings.json"
out="$(run)"
printf '%s' "$out" | grep -q 'my-be — no \.claude/hooks/workspace-guards\.sh' \
  && t_bad "guards:false excludes the repo from the stub check" "no mention of my-be" "$out" || t_ok "guards:false excludes the repo from the stub check"
printf '%s' "$out" | grep -q 'ok   my-app — workspace guards stub in place and registered' \
  && t_ok "guards:false leaves other repos checked" || t_bad "guards:false leaves other repos checked" "ok my-app" "$out"

# the configured mirror branch is not reported as stale even though its
# content already equals the trunk
make_multi "$TMP/f-mirror"; export WORKSPACE_ROOT="$TMP/f-mirror"
git clone -q "$TMP/f-mirror/my-app" "$TMP/f-mirror-origin" --bare
git -C "$TMP/f-mirror/my-app" remote add origin "$TMP/f-mirror-origin"
git -C "$TMP/f-mirror/my-app" fetch -q origin
out="$(run)"
printf '%s' "$out" | grep -q 'ok   my-app — no local branch already contained in develop' \
  && t_ok "mirror branch (main) not reported stale" || t_bad "mirror not stale" "ok   my-app — no local branch already contained in develop" "$out"

# exit code: 0 with warnings only, 1 when anything failed
make_mono "$TMP/f-exit-warn"; export WORKSPACE_ROOT="$TMP/f-exit-warn"
printf '# rules\n' > "$TMP/f-exit-warn/CLAUDE.md"; ln -s CLAUDE.md "$TMP/f-exit-warn/AGENTS.md"
mkdir -p "$TMP/f-exit-warn/.claude"; printf '{"x":"workspace-guards.sh"}' > "$TMP/f-exit-warn/.claude/settings.json"
git -C "$TMP/f-exit-warn" add -A; git -C "$TMP/f-exit-warn" commit -qm setup
out="$(run)"; rc=$?
printf '%s' "$out" | grep -q '^0 fail, [1-9][0-9]* warn$' \
  && t_ok "warnings alone leave the report at 0 fail" || t_bad "0 fail with warns" "0 fail, N warn" "$out"
is "warnings alone exit 0" "0" "$rc"

make_multi "$TMP/f-exit-fail"; export WORKSPACE_ROOT="$TMP/f-exit-fail"
out="$(run)"; rc=$?
is "any FAIL exits 1" "1" "$rc"

# the env-example rule: a key documented only in its OWN example (not the
# base one) must not be reported as undocumented — the case the source has
# a comment about.
make_multi "$TMP/f-env-own"; export WORKSPACE_ROOT="$TMP/f-env-own"
printf 'FOO=\n' > "$TMP/f-env-own/my-app/.env.example"
printf 'FOO=1\n' > "$TMP/f-env-own/my-app/.env"
printf 'BAR=\n' > "$TMP/f-env-own/my-app/.env.production.example"
printf 'BAR=2\n' > "$TMP/f-env-own/my-app/.env.production"
out="$(run)"
printf '%s' "$out" | grep -q 'ok   my-app — every key appears in its .env.example' \
  && t_ok "key documented only in its own example is not flagged" || t_bad "own example" "ok   my-app — every key appears in its .env.example" "$out"
printf '%s' "$out" | grep -q 'BAR' \
  && t_bad "BAR never named as undocumented" "no mention of BAR" "$out" || t_ok "BAR never named as undocumented"

echo "regression: the two review fixes"

# Fix 1 — capture-then-grep, not a direct pipe. Under test/lib.sh's
# set -o pipefail, `run | grep -q pattern` reports failure even when grep
# matches, because bin/doctor's own nonzero exit (correct, on a real FAIL)
# wins the pipeline's exit status. This asserts a real FAIL string is
# findable in captured output while doctor's own exit code is independently
# 1 — which is exactly what breaks if this reverts to piping run directly
# into grep.
make_multi "$TMP/f-regress-pipe"; export WORKSPACE_ROOT="$TMP/f-regress-pipe"
out="$(run)"; rc=$?
is "regression: doctor exits 1 on a real FAIL" "1" "$rc"
printf '%s' "$out" | grep -q 'FAIL my-app — no CLAUDE.md and no AGENTS.md' \
  && t_ok "regression: FAIL string still found via captured output" || t_bad "regression pipe" "FAIL my-app — no CLAUDE.md and no AGENTS.md" "$out"

# Fix 2 — the worktree comparison resolves the git toplevel instead of
# comparing $dir verbatim. Build the workspace under a symlinked path (like
# macOS's /tmp -> /private/tmp) so `git worktree list --porcelain` reports a
# different string than $WORKSPACE_ROOT/my-app; a raw string comparison
# would misidentify the main checkout as a stale worktree.
mkdir -p "$TMP/wt-real"
git_init "$TMP/wt-real/my-app"
printf 'name: demo\nversion: 1.0.0+1\n' > "$TMP/wt-real/my-app/pubspec.yaml"
git -C "$TMP/wt-real/my-app" add -A; git -C "$TMP/wt-real/my-app" commit -qm pubspec
ln -s "$TMP/wt-real" "$TMP/wt-link"
cat > "$TMP/wt-link/workspace.yml" <<'EOF'
name: WT
shape: multi-repo
repos:
  app: { path: my-app, trunk: main, role: release-anchor }
release:
  adapter: flutter-shorebird
  anchor_file: my-app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/core/services/api_service]
EOF
export WORKSPACE_ROOT="$TMP/wt-link"
printf '# rules\n' > "$TMP/wt-link/my-app/CLAUDE.md"; ln -s CLAUDE.md "$TMP/wt-link/my-app/AGENTS.md"
mkdir -p "$TMP/wt-link/my-app/.claude/hooks"
cp "$KIT/hooks/workspace-guards.stub.sh" "$TMP/wt-link/my-app/.claude/hooks/workspace-guards.sh"
printf '{"x":"workspace-guards.sh"}' > "$TMP/wt-link/my-app/.claude/settings.json"
mkdir -p "$TMP/wt-link/.claude"; cp "$TMP/wt-link/my-app/.claude/settings.json" "$TMP/wt-link/.claude/settings.json"
out="$(run)"
printf '%s' "$out" | grep -q 'predates the guard stub' \
  && t_bad "regression: no false worktree warning under a symlinked root" "no such warning" "$out" \
  || t_ok "regression: no false worktree warning under a symlinked root"
printf '%s' "$out" | grep -q 'ok   my-app — workspace guards stub in place and registered' \
  && t_ok "regression: stub check still passes under a symlinked root" || t_bad "regression symlink" "ok   my-app — workspace guards stub in place and registered" "$out"

finish
