#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

echo "guard-release"
is "plain command stays silent" "" "$(payload 'git status' | bash "$KIT/hooks/guard-release.sh")"
payload 'pnpm exec agent-workspace-kit release cut patch production ios --items 1' | bash "$KIT/hooks/guard-release.sh" | grep -q '"permissionDecision": "ask"' && t_ok "release cut asks" || t_bad "release cut" "ask" "silent"
payload 'scripts/release-submit.sh production ios --submit-for-review' | bash "$KIT/hooks/guard-release.sh" | grep -q 'not reversible' && t_ok "submit asks" || t_bad "submit" "ask" "silent"
is "malformed json stays silent" "" "$(printf 'not json' | bash "$KIT/hooks/guard-release.sh")"
is "empty input stays silent" "" "$(printf '' | bash "$KIT/hooks/guard-release.sh")"

echo "guard-pr-contract"
is "non-PR command stays silent" "" "$(payload 'git status' | bash "$KIT/hooks/guard-pr-contract.sh")"
is "malformed json stays silent" "" "$(printf 'not json' | bash "$KIT/hooks/guard-pr-contract.sh")"
is "empty input stays silent" "" "$(printf '' | bash "$KIT/hooks/guard-pr-contract.sh")"

echo "stub relay"
make_multi "$TMP/m"; export WORKSPACE_ROOT="$TMP/m"
mkdir -p "$TMP/m/node_modules"; ln -s "$KIT" "$TMP/m/node_modules/agent-workspace-kit"
mkdir -p "$TMP/m/my-app/.claude/hooks"; cp "$KIT/hooks/workspace-guards.stub.sh" "$TMP/m/my-app/.claude/hooks/workspace-guards.sh"
out="$(cd "$TMP/m/my-app" && payload 'bin/release-cut release production both' | sh .claude/hooks/workspace-guards.sh)"
printf '%s' "$out" | grep -q '"ask"' && t_ok "product repo relays to the kit" || t_bad "relay" "ask" "$out"

mkdir -p "$TMP/m/my-app/.claude/worktrees/t"; git -C "$TMP/m/my-app" worktree add -q "$TMP/m/my-app/.claude/worktrees/t" -b t develop
mkdir -p "$TMP/m/my-app/.claude/worktrees/t/.claude/hooks"
cp "$KIT/hooks/workspace-guards.stub.sh" "$TMP/m/my-app/.claude/worktrees/t/.claude/hooks/workspace-guards.sh"
out="$(cd "$TMP/m/my-app/.claude/worktrees/t" && payload 'bin/release-cut x' | sh .claude/hooks/workspace-guards.sh)"
printf '%s' "$out" | grep -q '"ask"' && t_ok "a worktree relays too" || t_bad "worktree relay" "ask" "$out"

# "workspace root" here means a monorepo whose root is the git toplevel
# itself — the top/node_modules candidate, as opposed to the
# dirname(top)/node_modules candidate a product repo hits above.
make_mono "$TMP/wr"
mkdir -p "$TMP/wr/node_modules"; ln -s "$KIT" "$TMP/wr/node_modules/agent-workspace-kit"
out="$(cd "$TMP/wr" && payload 'bin/release-cut x' | sh "$KIT/hooks/workspace-guards.stub.sh")"
printf '%s' "$out" | grep -q '"ask"' && t_ok "workspace root relays too" || t_bad "root relay" "ask" "$out"

is "no kit above: silent" "" "$(cd "$TMP" && git_init "$TMP/lone" >/dev/null; cd "$TMP/lone" && payload 'bin/release-cut x' | sh "$KIT/hooks/workspace-guards.stub.sh")"

is "session-start: no output when clean fails but at least never crashes (exit 0)" "0" "$(cd "$TMP/m/my-app" && sh .claude/hooks/workspace-guards.sh session-start >/dev/null 2>&1; echo $?)"

echo "the relay is byte-identical to the canonical stub"
cmp -s "$TMP/m/my-app/.claude/hooks/workspace-guards.sh" "$KIT/hooks/workspace-guards.stub.sh" \
  && t_ok "installed copy matches the canonical file" || t_bad "byte-identical" "match" "differ"

echo "git hooks"
bash "$KIT/bin/install-git-hooks" >/dev/null
[ -x "$TMP/m/my-app/.git/hooks/post-merge" ] && t_ok "post-merge in the anchor" || t_bad "post-merge" "installed" "missing"
[ -x "$TMP/m/my-be/.git/hooks/post-merge" ] && t_bad "post-merge only in the anchor" "absent" "present" || t_ok "post-merge only in the anchor"
[ -x "$TMP/m/my-be/.git/hooks/pre-commit" ] && t_ok "pre-commit everywhere" || t_bad "pre-commit" "installed" "missing"
grep -q '"develop"' "$TMP/m/my-app/.git/hooks/post-merge" && t_ok "trunk substituted" || t_bad "trunk" "develop" "$(grep TRUNK "$TMP/m/my-app/.git/hooks/post-merge")"
(cd "$TMP/m/my-be" && git checkout -q main && echo x > f && git add f && git commit -qm "on trunk") 2>/dev/null && t_bad "pre-commit refuses trunk" "refused" "committed" || t_ok "pre-commit refuses trunk"
(cd "$TMP/m/my-be" && git checkout -q main && echo y > g && git add g && git commit -qm "forced" --no-verify) >/dev/null 2>&1 && t_ok "pre-commit lets --no-verify through" || t_bad "no-verify" "committed" "refused"
git -C "$TMP/m/my-be" checkout -q --detach >/dev/null 2>&1
git -C "$TMP/m/my-be" worktree add -q "$TMP/m/my-be-wt" main >/dev/null 2>&1
(cd "$TMP/m/my-be-wt" && echo z > h && git add h && git commit -qm "in a trunk worktree") >/dev/null 2>&1 && t_ok "pre-commit allows a worktree of the trunk" || t_bad "worktree of trunk" "committed" "refused"
postmerge_out="$(cd "$TMP/m/my-app" && git checkout -q develop 2>/dev/null; git merge -q --no-edit main >/dev/null 2>&1; ./.git/hooks/post-merge; printf 'ok-exit\n')"
printf '%s' "$postmerge_out" | grep -q 'ok-exit' && t_ok "post-merge never fails the merge" || t_bad "post-merge failing" "ok-exit" "no output"

echo "husky"
make_mono "$TMP/o"; export WORKSPACE_ROOT="$TMP/o"; mkdir -p "$TMP/o/.husky"; printf '#!/usr/bin/env sh\npnpm exec lint-staged\n' > "$TMP/o/.husky/pre-commit"
bash "$KIT/bin/install-git-hooks" >/dev/null
grep -q 'awk-pre-commit' "$TMP/o/.husky/pre-commit" && t_ok "appended to husky pre-commit" || t_bad "husky" "awk-pre-commit" "$(cat "$TMP/o/.husky/pre-commit")"
grep -q 'lint-staged' "$TMP/o/.husky/pre-commit" && t_ok "kept the existing line" || t_bad "kept" "lint-staged" "gone"
[ -f "$TMP/o/.husky/awk-post-merge" ] && t_ok "post-merge via husky" || t_bad "post-merge husky" "file" "missing"
bash "$KIT/bin/install-git-hooks" >/dev/null
is "idempotent" "1" "$(grep -c awk-pre-commit "$TMP/o/.husky/pre-commit")"

echo "doctor: husky file that exists but does not invoke the kit's hook"
make_multi "$TMP/f-husky-noinvoke"; export WORKSPACE_ROOT="$TMP/f-husky-noinvoke"
mkdir -p "$TMP/f-husky-noinvoke/my-app/.husky"
printf '#!/usr/bin/env sh\necho hi\n' > "$TMP/f-husky-noinvoke/my-app/.husky/post-merge"
out="$(bash "$KIT/bin/doctor" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'post-merge not installed' && t_ok "husky file with no invocation reports not installed" || t_bad "husky no-invoke" "not installed" "$out"

finish
