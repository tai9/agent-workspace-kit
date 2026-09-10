#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- brief's own sketch: report, then apply, then converge on the 2nd platform
echo "brief sketch"
make_multi "$TMP/m"; export WORKSPACE_ROOT="$TMP/m"; R="$TMP/m/my-app"
git_init "$TMP/origin"; git -C "$TMP/origin" config receive.denyCurrentBranch ignore
git -C "$R" remote add origin "$TMP/origin"; git -C "$R" push -q origin main develop
git -C "$R" checkout -q develop; c=$(commit_file "$R" lib/a.dart "fix: a"); git -C "$R" tag released/1.9.1+76
mkdir -p "$TMP/m/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/m/releases/1.9.1+76.md"
cat >> "$TMP/m/workspace.yml" <<'EOF'
post_release:
  - "echo post {version} {build} {platform} {extra} >> post.log"
EOF
echo "report"
out="$(bash "$KIT/bin/release-live" 1.9.1+76 2>&1 | strip_ansi)"; rc=$?
is "report exits 0" "0" "$rc"
printf '%s' "$out" | grep -q '=== Demo 1.9.1+76 — go-live check ===' && t_ok "heading" || t_bad "heading" "Demo" "$out"
printf '%s' "$out" | grep -q '! not pushed to origin yet' && t_ok "sees the unpushed tag" || t_bad "tag" "not pushed" "$out"
printf '%s' "$out" | grep -q 'origin/main does NOT contain released/1.9.1+76' && t_ok "mirror behind" || t_bad "mirror" "does NOT contain" "$out"
printf '%s' "$out" | grep -q 'post_release: echo post 1.9.1+76 76 both' && t_ok "lists post commands" || t_bad "post" "echo post" "$out"
printf '%s' "$out" | grep -q 'Report only — nothing was changed' && t_ok "report only" || t_bad "report only" "nothing was changed" "$out"
[ -f "$TMP/m/post.log" ] && t_bad "report runs nothing" "no log" "log" || t_ok "report runs nothing"
echo "apply"
bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply --post --post-args "--min 70" >/dev/null 2>&1
is "note status moved" "- **Status:** live $(date +%Y-%m-%d) — iOS ✅ · Android ⏳ (build 76)" "$(head -1 "$TMP/m/releases/1.9.1+76.md")"
git -C "$TMP/origin" tag | grep -q released/1.9.1+76 && t_ok "tag pushed" || t_bad "tag pushed" "tag" "none"
is "post ran with args" "post 1.9.1+76 76 ios --min 70" "$(cat "$TMP/m/post.log")"
bash "$KIT/bin/release-live" 1.9.1+76 --platform android --apply --merge-mirror >/dev/null 2>&1
is "second platform keeps the first" "- **Status:** live $(date +%Y-%m-%d) — iOS ✅ · Android ✅ (build 76)" "$(head -1 "$TMP/m/releases/1.9.1+76.md")"
git -C "$R" merge-base --is-ancestor released/1.9.1+76 origin/main && t_ok "mirror merged when both live" || t_bad "mirror merged" "ancestor" "not"

# --- no-flag report is read-only: prove it with a full before/after snapshot
echo "read-only proof"
make_multi "$TMP/ro"; export WORKSPACE_ROOT="$TMP/ro"; RO="$TMP/ro/my-app"
git_init "$TMP/ro-origin"; git -C "$TMP/ro-origin" config receive.denyCurrentBranch ignore
git -C "$RO" remote add origin "$TMP/ro-origin"; git -C "$RO" push -q origin main develop
git -C "$RO" checkout -q develop; commit_file "$RO" lib/a.dart "fix: a" >/dev/null; git -C "$RO" tag released/1.9.1+76
mkdir -p "$TMP/ro/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/ro/releases/1.9.1+76.md"
cat >> "$TMP/ro/workspace.yml" <<'EOF'
post_release:
  - "echo should-not-run >> should-not-exist.log"
EOF
# Excludes refs/remotes/** (incl. their reflogs) and FETCH_HEAD: the report
# deliberately fetches the mirror branch (a read of the remote, restoring
# accuracy the reviewer required) which legitimately updates those two
# remote-tracking bookkeeping paths. Nothing a person owns — the working
# tree, local branches/tags, notes, the inventory — may still move.
snapshot() {
  find "$1" -type f \
    -not -path '*/.git/refs/remotes/*' \
    -not -path '*/.git/logs/refs/remotes/*' \
    -not -name 'FETCH_HEAD' \
    -exec sha256sum {} \; 2>/dev/null | sed "s#$1/##" | sort
}
# Local refs, excluding refs/remotes/** for the same reason the snapshot does.
local_refs() { git -C "$1" for-each-ref --format='%(refname) %(objectname)' | grep -v '^refs/remotes/' | sort; }
snapshot "$TMP/ro" > "$TMP/ro-before.txt"
tags_before="$(git -C "$RO" tag --list | sort)"
refs_before="$(local_refs "$RO")"
origin_refs_before="$(git -C "$TMP/ro-origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
bash "$KIT/bin/release-live" 1.9.1+76 >/dev/null 2>&1
bash "$KIT/bin/release-live" 1.9.1+76 --dry-run >/dev/null 2>&1
snapshot "$TMP/ro" > "$TMP/ro-after.txt"
is "read-only: no file content changed" "$(cat "$TMP/ro-before.txt")" "$(cat "$TMP/ro-after.txt")"
is "read-only: no local tags changed" "$tags_before" "$(git -C "$RO" tag --list | sort)"
is "read-only: no local refs changed" "$refs_before" "$(local_refs "$RO")"
is "read-only: origin refs unchanged" "$origin_refs_before" "$(git -C "$TMP/ro-origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
[ -f "$TMP/ro/should-not-exist.log" ] && t_bad "read-only: post_release never ran" "no log" "log" || t_ok "read-only: post_release never ran"

# --- the report's fetch does its job: a stale local remote-tracking ref must
# not make the report lie about the mirror. Push the merge from a SECOND
# clone (so this repo's own refs/remotes/origin/main is left stale), then
# assert the no-flag report still sees the mirror as up to date.
echo "fetch keeps the report accurate"
make_multi "$TMP/fr"; export WORKSPACE_ROOT="$TMP/fr"; FR="$TMP/fr/my-app"
git_init "$TMP/fr-origin"; git -C "$TMP/fr-origin" config receive.denyCurrentBranch ignore
git -C "$FR" remote add origin "$TMP/fr-origin"; git -C "$FR" push -q origin main develop
git -C "$FR" checkout -q develop; commit_file "$FR" lib/a.dart "fix: a" >/dev/null; git -C "$FR" tag released/1.9.1+76
git -C "$FR" push -q origin refs/tags/released/1.9.1+76
mkdir -p "$TMP/fr/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/fr/releases/1.9.1+76.md"
# A second, independent clone merges the tag into main and pushes it —
# $FR's own refs/remotes/origin/main never saw this push.
git clone -q "$TMP/fr-origin" "$TMP/fr-clone2" >/dev/null 2>&1
git -C "$TMP/fr-clone2" checkout -q main
git -C "$TMP/fr-clone2" merge --no-ff -q released/1.9.1+76 -m "merge from clone2"
git -C "$TMP/fr-clone2" push -q origin main
out="$(bash "$KIT/bin/release-live" 1.9.1+76 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'origin/main already contains released/1.9.1+76' && t_ok "fetch sees the mirror is already up to date" || t_bad "fetch keeps report accurate" "origin/main already contains" "$out"
printf '%s' "$out" | grep -q 'does NOT contain' && t_bad "fetch: no stale does-NOT-contain warning" "absent" "present" || t_ok "fetch: no stale does-NOT-contain warning"

# --- no network: a remote that cannot be reached warns and still reports ---
echo "no network"
make_multi "$TMP/nn"; export WORKSPACE_ROOT="$TMP/nn"; NN="$TMP/nn/my-app"
git -C "$NN" remote add origin "$TMP/nn/does-not-exist"
git -C "$NN" checkout -q develop; commit_file "$NN" lib/a.dart "fix: a" >/dev/null; git -C "$NN" tag released/1.9.1+76
mkdir -p "$TMP/nn/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/nn/releases/1.9.1+76.md"
out="$(bash "$KIT/bin/release-live" 1.9.1+76 2>&1 | strip_ansi)"; rc=$?
is "no network: report still exits 0" "0" "$rc"
printf '%s' "$out" | grep -q 'could not fetch origin/main' && t_ok "no network: warns about the failed fetch" || t_bad "no network: warns" "could not fetch origin/main" "$out"
printf '%s' "$out" | grep -q '=== Plan for' && t_ok "no network: still produces a plan" || t_bad "no network: still produces a plan" "=== Plan for" "$out"

# --- convergence: both orders, and re-running the same platform twice -------
echo "convergence"
setup_conv() { # <dir>
  make_multi "$TMP/$1"; RC="$TMP/$1/my-app"
  git_init "$TMP/$1-origin"; git -C "$TMP/$1-origin" config receive.denyCurrentBranch ignore
  git -C "$RC" remote add origin "$TMP/$1-origin"; git -C "$RC" push -q origin main develop
  git -C "$RC" checkout -q develop; commit_file "$RC" lib/a.dart "fix: a" >/dev/null; git -C "$RC" tag released/1.9.1+76
  mkdir -p "$TMP/$1/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/$1/releases/1.9.1+76.md"
}

setup_conv c1; export WORKSPACE_ROOT="$TMP/c1"
bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply >/dev/null 2>&1
bash "$KIT/bin/release-live" 1.9.1+76 --platform android --apply >/dev/null 2>&1
is "iOS then Android converges" "- **Status:** live $(date +%Y-%m-%d) — iOS ✅ · Android ✅ (build 76)" "$(head -1 "$TMP/c1/releases/1.9.1+76.md")"

setup_conv c2; export WORKSPACE_ROOT="$TMP/c2"
bash "$KIT/bin/release-live" 1.9.1+76 --platform android --apply >/dev/null 2>&1
bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply >/dev/null 2>&1
is "Android then iOS converges" "- **Status:** live $(date +%Y-%m-%d) — iOS ✅ · Android ✅ (build 76)" "$(head -1 "$TMP/c2/releases/1.9.1+76.md")"

setup_conv c3; export WORKSPACE_ROOT="$TMP/c3"
bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply >/dev/null 2>&1
bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply >/dev/null 2>&1
is "same platform twice stays put" "- **Status:** live $(date +%Y-%m-%d) — iOS ✅ · Android ⏳ (build 76)" "$(head -1 "$TMP/c3/releases/1.9.1+76.md")"

# --- mirror merge behavior ---------------------------------------------------
echo "mirror merge"
setup_merge() { # <dir>
  make_multi "$TMP/$1"; RM="$TMP/$1/my-app"
  git_init "$TMP/$1-origin"; git -C "$TMP/$1-origin" config receive.denyCurrentBranch ignore
  git -C "$RM" remote add origin "$TMP/$1-origin"; git -C "$RM" push -q origin main develop
  git -C "$RM" checkout -q develop; commit_file "$RM" lib/a.dart "fix: a" >/dev/null; git -C "$RM" tag released/1.9.1+76
  mkdir -p "$TMP/$1/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/$1/releases/1.9.1+76.md"
}

# skipped with one platform, no force
setup_merge mg1; export WORKSPACE_ROOT="$TMP/mg1"; RM="$TMP/mg1/my-app"
out="$(bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply --merge-mirror 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'skipping the main merge' || printf '%s' "$out" | grep -q 'skipping the .* merge' \
  && t_ok "merge skipped with one platform" || t_bad "merge skipped" "skipping the ... merge" "$out"
git -C "$RM" merge-base --is-ancestor released/1.9.1+76 origin/main 2>/dev/null && t_bad "not merged with one platform" "not ancestor" "ancestor" || t_ok "not merged with one platform"

# done with both
setup_merge mg2; export WORKSPACE_ROOT="$TMP/mg2"; RM="$TMP/mg2/my-app"
bash "$KIT/bin/release-live" 1.9.1+76 --platform both --apply --merge-mirror >/dev/null 2>&1
git -C "$RM" merge-base --is-ancestor released/1.9.1+76 origin/main && t_ok "merged with both platforms" || t_bad "merged with both" "ancestor" "not"

# done with one platform plus force
setup_merge mg3; export WORKSPACE_ROOT="$TMP/mg3"; RM="$TMP/mg3/my-app"
bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply --merge-mirror --force-merge >/dev/null 2>&1
git -C "$RM" merge-base --is-ancestor released/1.9.1+76 origin/main && t_ok "merged with one platform + force" || t_bad "merged with force" "ancestor" "not"

# refused on a dirty tree
setup_merge mg4; export WORKSPACE_ROOT="$TMP/mg4"; RM="$TMP/mg4/my-app"
echo dirty >> "$RM/lib/a.dart"
out="$(bash "$KIT/bin/release-live" 1.9.1+76 --platform both --apply --merge-mirror 2>&1 | strip_ansi)"; rc=$?
[ "$rc" -ne 0 ] && t_ok "dirty tree merge exits non-zero" || t_bad "dirty tree merge exits non-zero" "nonzero" "0"
printf '%s' "$out" | grep -qi 'dirty' && t_ok "dirty tree merge message" || t_bad "dirty tree merge message" "dirty" "$out"
git -C "$RM" checkout -q -- lib/a.dart

# returns to the original branch afterwards
setup_merge mg5; export WORKSPACE_ROOT="$TMP/mg5"; RM="$TMP/mg5/my-app"
git -C "$RM" checkout -q develop
bash "$KIT/bin/release-live" 1.9.1+76 --platform both --apply --merge-mirror >/dev/null 2>&1
is "back on develop after merge" "develop" "$(git -C "$RM" branch --show-current)"

# --- trunk stays unshipped: a post-tag trunk commit must NOT reach the mirror
echo "trunk vs mirror"
setup_merge tk1; export WORKSPACE_ROOT="$TMP/tk1"; RM="$TMP/tk1/my-app"
commit_file "$RM" lib/unshipped.dart "feat: not in this release" >/dev/null
bash "$KIT/bin/release-live" 1.9.1+76 --platform both --apply --merge-mirror >/dev/null 2>&1
git -C "$RM" show origin/main:lib/unshipped.dart >/dev/null 2>&1 && t_bad "unshipped trunk commit stays off the mirror" "absent" "present" || t_ok "unshipped trunk commit stays off the mirror"
git -C "$RM" merge-base --is-ancestor released/1.9.1+76 origin/main && t_ok "tag itself still merged" || t_bad "tag itself still merged" "ancestor" "not"

# --- --post: first command fails, second must not run, exit non-zero -------
echo "post failure"
setup_conv pf1; export WORKSPACE_ROOT="$TMP/pf1"
cat >> "$TMP/pf1/workspace.yml" <<EOF
post_release:
  - "exit 3"
  - "echo should-not-run >> $TMP/pf1/second.log"
EOF
bash "$KIT/bin/release-live" 1.9.1+76 --apply --post >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && t_ok "post failure: non-zero exit" || t_bad "post failure: non-zero exit" "nonzero" "0"
[ -f "$TMP/pf1/second.log" ] && t_bad "post failure: second command did not run" "no log" "log" || t_ok "post failure: second command did not run"

# --- --post substitutes all four placeholders, {extra} empty w/o --post-args
echo "post placeholders"
setup_conv pp1; export WORKSPACE_ROOT="$TMP/pp1"
cat >> "$TMP/pp1/workspace.yml" <<EOF
post_release:
  - "printf 'v=%s b=%s p=%s e=[%s]' {version} {build} {platform} '{extra}' >> $TMP/pp1/args.log"
EOF
bash "$KIT/bin/release-live" 1.9.1+76 --platform ios --apply --post >/dev/null 2>&1
is "post substitutes all placeholders, empty extra" "v=1.9.1+76 b=76 p=ios e=[]" "$(cat "$TMP/pp1/args.log")"

# --- report lists post commands but runs none (file assertion) -------------
echo "post report-only"
setup_conv pr1; export WORKSPACE_ROOT="$TMP/pr1"
cat >> "$TMP/pr1/workspace.yml" <<EOF
post_release:
  - "echo ran >> $TMP/pr1/marker.log"
EOF
out="$(bash "$KIT/bin/release-live" 1.9.1+76 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'post_release: echo ran' && t_ok "report lists the post command" || t_bad "report lists post" "echo ran" "$out"
[ -f "$TMP/pr1/marker.log" ] && t_bad "report never runs post commands" "no marker" "marker" || t_ok "report never runs post commands"

# --- no mirror configured: --merge-mirror dies, other steps still work -----
echo "no mirror"
make_multi "$TMP/nm"; export WORKSPACE_ROOT="$TMP/nm"; NM="$TMP/nm/my-app"
sed -i.bak 's/, mirror: main//' "$TMP/nm/workspace.yml"; rm -f "$TMP/nm/workspace.yml.bak"
git_init "$TMP/nm-origin"; git -C "$TMP/nm-origin" config receive.denyCurrentBranch ignore
git -C "$NM" remote add origin "$TMP/nm-origin"; git -C "$NM" push -q origin main develop
git -C "$NM" checkout -q develop; commit_file "$NM" lib/a.dart "fix: a" >/dev/null; git -C "$NM" tag released/1.9.1+76
mkdir -p "$TMP/nm/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/nm/releases/1.9.1+76.md"
out="$(bash "$KIT/bin/release-live" 1.9.1+76 --apply --merge-mirror 2>&1 | strip_ansi)"; rc=$?
[ "$rc" -ne 0 ] && t_ok "no mirror: --merge-mirror dies" || t_bad "no mirror: --merge-mirror dies" "nonzero" "0"
printf '%s' "$out" | grep -qF "no mirror branch configured for app" && t_ok "no mirror: clear message" || t_bad "no mirror: clear message" "no mirror branch configured for app" "$out"
[ "$(head -1 "$TMP/nm/releases/1.9.1+76.md")" = "- **Status:** released 2026-09-09" ] && t_ok "no mirror: note untouched on the dying run" || t_bad "no mirror: note untouched" "unchanged" "$(head -1 "$TMP/nm/releases/1.9.1+76.md")"
bash "$KIT/bin/release-live" 1.9.1+76 --apply >/dev/null 2>&1
is "no mirror: other steps still work" "- **Status:** live $(date +%Y-%m-%d) — iOS ✅ · Android ✅ (build 76)" "$(head -1 "$TMP/nm/releases/1.9.1+76.md")"
git -C "$TMP/nm-origin" tag | grep -q released/1.9.1+76 && t_ok "no mirror: tag still pushed" || t_bad "no mirror: tag pushed" "tag" "none"

# --- blocking problems: missing note, missing tag ---------------------------
echo "blocking problems"
make_multi "$TMP/bn"; export WORKSPACE_ROOT="$TMP/bn"; BN="$TMP/bn/my-app"
git_init "$TMP/bn-origin"; git -C "$TMP/bn-origin" config receive.denyCurrentBranch ignore
git -C "$BN" remote add origin "$TMP/bn-origin"; git -C "$BN" push -q origin main develop
git -C "$BN" checkout -q develop; commit_file "$BN" lib/a.dart "fix: a" >/dev/null; git -C "$BN" tag released/1.9.1+76
# no releases/1.9.1+76.md written
out="$(bash "$KIT/bin/release-live" 1.9.1+76 2>&1 | strip_ansi)"; rc=$?
[ "$rc" -ne 0 ] && t_ok "missing note: non-zero exit" || t_bad "missing note: non-zero exit" "nonzero" "0"
printf '%s' "$out" | grep -q 'release note not found' && t_ok "missing note: reported" || t_bad "missing note: reported" "release note not found" "$out"
printf '%s' "$out" | grep -q 'Blocking problems above' && t_ok "missing note: blocking message" || t_bad "missing note: blocking" "Blocking problems" "$out"

make_multi "$TMP/bt"; export WORKSPACE_ROOT="$TMP/bt"; BT="$TMP/bt/my-app"
git_init "$TMP/bt-origin"; git -C "$TMP/bt-origin" config receive.denyCurrentBranch ignore
git -C "$BT" remote add origin "$TMP/bt-origin"; git -C "$BT" push -q origin main develop
git -C "$BT" checkout -q develop; commit_file "$BT" lib/a.dart "fix: a" >/dev/null
mkdir -p "$TMP/bt/releases"; printf -- '- **Status:** released 2026-09-09\n' > "$TMP/bt/releases/1.9.1+76.md"
# no tag created
out="$(bash "$KIT/bin/release-live" 1.9.1+76 2>&1 | strip_ansi)"; rc=$?
[ "$rc" -ne 0 ] && t_ok "missing tag: non-zero exit" || t_bad "missing tag: non-zero exit" "nonzero" "0"
printf '%s' "$out" | grep -q 'tag released/1.9.1+76 does not exist' && t_ok "missing tag: reported" || t_bad "missing tag: reported" "does not exist" "$out"
printf '%s' "$out" | grep -q 'Blocking problems above' && t_ok "missing tag: blocking message" || t_bad "missing tag: blocking" "Blocking problems" "$out"

finish
