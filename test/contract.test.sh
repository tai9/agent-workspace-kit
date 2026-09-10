#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

add_contracts() { # <workspace.yml>
  cat >> "$1" <<'YML'
contracts:
  - name: promo
    paths: { app: lib/features/promo, backend: promo }
  - name: offers
    paths: { app: lib/features/payment, backend: offers }
YML
}

echo "step 1 — brief's sketch (multi-repo)"

make_multi "$TMP/m"; export WORKSPACE_ROOT="$TMP/m"; R="$TMP/m/my-app"; B="$TMP/m/my-be"
add_contracts "$TMP/m/workspace.yml"
git_init "$TMP/origin"; git -C "$TMP/origin" config receive.denyCurrentBranch ignore
for r in "$R" "$B"; do git -C "$r" remote add origin "$TMP/origin"; done
# my-be first: my-app's root commit is a byte-identical fast-forward ancestor
# of my-app's own push (both git_init roots share the same pinned SHA), so
# pushing my-be after my-app would try to rewind origin/main and be rejected
# as a non-fast-forward. Pushing my-be first makes it a no-op push that still
# leaves my-be with a resolvable local origin/main tracking ref.
git -C "$B" push -q origin main
git -C "$R" push -q origin main develop
git -C "$R" checkout -q -b feat develop; commit_file "$R" lib/features/promo/x.dart "app side" >/dev/null

out="$(cd "$R" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'promo — this change touches it here.' && t_ok "detects the contract" || t_bad "detect" "promo" "$out"
printf '%s' "$out" | grep -q '?    my-be has nothing matching /promo/' && t_ok "asks about the other side" || t_bad "asks" "?" "$out"

mkdir -p "$B/src/promo"; echo x > "$B/src/promo/y.ts"
out="$(cd "$R" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'ok   my-be has 1 uncommitted or unmerged file(s) matching /promo/' && t_ok "sees uncommitted work on the other side" || t_bad "sees" "ok" "$out"

out="$(cd "$B" && bash "$KIT/bin/contract-check" 2>&1)"
rc=$?
printf '%s' "$out" | grep -q 'no changes against origin/main' && t_ok "clean repo says so" || t_bad "clean" "no changes" "$out"
is "clean repo exits 0" "0" "$rc"

echo "multi-repo — worktrees, no-touch, two contracts, exit code"

make_multi "$TMP/m2"; export WORKSPACE_ROOT="$TMP/m2"; R="$TMP/m2/my-app"; B="$TMP/m2/my-be"
add_contracts "$TMP/m2/workspace.yml"
git_init "$TMP/origin2"; git -C "$TMP/origin2" config receive.denyCurrentBranch ignore
for r in "$R" "$B"; do git -C "$r" remote add origin "$TMP/origin2"; done
git -C "$B" push -q origin main
git -C "$R" push -q origin main develop
git -C "$R" checkout -q -b feat develop
commit_file "$R" lib/features/promo/a.dart "a" >/dev/null

# a change touching no contract prints no contract block
out="$(cd "$R" && bash "$KIT/bin/contract-check" origin/develop~1 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -qiE 'promo|offers' \
  && t_bad "no-touch commit still prints a contract block" "no contract block" "$out" \
  || t_ok "no-touch diff prints no contract block"

# the paired work sits in a worktree, not the sibling's trunk
git -C "$B" worktree add -q -b be-feat "$TMP/m2/my-be-wt"
commit_file "$TMP/m2/my-be-wt" src/promo/z.ts "be side in a worktree" >/dev/null
out="$(cd "$R" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'ok   my-be has 1 uncommitted or unmerged file(s) matching /promo/' \
  && t_ok "finds paired work sitting in the sibling's worktree" || t_bad "worktree" "ok" "$out"

# two contracts touched by the same diff both report
commit_file "$R" lib/features/payment/b.dart "b" >/dev/null
out="$(cd "$R" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'promo — this change touches it here.' && t_ok "two contracts: promo reports" || t_bad "two/promo" "promo" "$out"
printf '%s' "$out" | grep -q 'offers — this change touches it here.' && t_ok "two contracts: offers reports" || t_bad "two/offers" "offers" "$out"

# a contract where the current repo has no pattern for it is skipped entirely
cat >> "$TMP/m2/workspace.yml" <<'YML'
  - name: landing-only
    paths: { backend: landing-only }
YML
out="$(cd "$R" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'landing-only' \
  && t_bad "contract with no pattern for this repo is skipped" "no mention" "$out" \
  || t_ok "contract with no pattern for this repo is skipped"

echo "usage errors"

out="$(cd "$TMP" && bash "$KIT/bin/contract-check" 2>&1)"; rc=$?
is "cwd outside any repo exits 2" "2" "$rc"

out="$(cd "$R" && bash "$KIT/bin/contract-check" no-such-repo 2>&1)"; rc=$?
is "unknown repo name exits 2" "2" "$rc"

echo "missing base ref"

out="$(cd "$R" && bash "$KIT/bin/contract-check" app definitely-not-a-ref 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'not found locally' && t_ok "missing base ref reports clearly" || t_bad "missing base" "not found locally" "$out"
printf '%s' "$out" | grep -q 'no changes' && t_bad "missing base ref must not read as a clean diff" "no such text" "$out" || t_ok "missing base ref is not confused with a clean diff"
is "missing base ref exits 0" "0" "$rc"

echo "explicit repo and base args"

out="$(cd "$TMP" && WORKSPACE_ROOT="$TMP/m2" bash "$KIT/bin/contract-check" app origin/develop 2>&1 | strip_ansi)"; rc=$?
printf '%s' "$out" | grep -q 'promo — this change touches it here.' && t_ok "explicit repo + base resolve the same diff" || t_bad "explicit args" "promo" "$out"
is "explicit repo + base exits 0" "0" "$rc"

echo "no contracts configured"

make_multi "$TMP/m3"; export WORKSPACE_ROOT="$TMP/m3"
out="$(cd "$TMP/m3/my-app" && bash "$KIT/bin/contract-check" 2>&1)"; rc=$?
is "no contracts: one line" "no contracts configured in workspace.yml" "$out"
is "no contracts: exits 0" "0" "$rc"

echo "monorepo — scoping across three roles"

git_init "$TMP/o"; mkdir -p "$TMP/o/app" "$TMP/o/backend" "$TMP/o/landing"
printf 'name: demo\nversion: 1.0.0+6\n' > "$TMP/o/app/pubspec.yaml"
cat > "$TMP/o/workspace.yml" <<'YML'
name: Demo
shape: monorepo
trunk: main
repos:
  app: { path: app, role: release-anchor, mirror: release }
  backend: { path: backend, role: service }
  landing: { path: landing, role: service }
release:
  adapter: flutter-shorebird
  anchor_file: app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/services/scorer]
contracts:
  - name: promo
    paths: { app: lib/features/promo, backend: promo }
YML
git -C "$TMP/o" add -A; git -C "$TMP/o" commit -qm "workspace"
export WORKSPACE_ROOT="$TMP/o"
git clone -q "$TMP/o" "$TMP/o-origin" --bare
git -C "$TMP/o" remote add origin "$TMP/o-origin"
git -C "$TMP/o" fetch -q origin
mkdir -p "$TMP/o/app/lib/features/promo"; echo x > "$TMP/o/app/lib/features/promo/x.dart"
git -C "$TMP/o" add -A; git -C "$TMP/o" commit -qm "app promo"

out="$(cd "$TMP/o/app" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q '?    backend has nothing matching /promo/' && t_ok "mono: detects the contract, asks about backend" || t_bad "mono detect" "?" "$out"

# work in a THIRD role's directory (landing) must not count as backend moving
mkdir -p "$TMP/o/landing/promo"; echo y > "$TMP/o/landing/promo/y.md"
out="$(cd "$TMP/o/app" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q '?    backend has nothing matching /promo/' \
  && t_ok "mono: a third role's directory does not count as the sibling moving" \
  || t_bad "mono third-role" "?" "$out"

mkdir -p "$TMP/o/backend/promo"; echo z > "$TMP/o/backend/promo/z.ts"
out="$(cd "$TMP/o/app" && bash "$KIT/bin/contract-check" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'ok   backend has 1 uncommitted or unmerged file(s) matching /promo/' \
  && t_ok "mono: uncommitted work scoped to backend's own subdir is found" \
  || t_bad "mono backend" "ok" "$out"

echo "monorepo — clean repo"

git_init "$TMP/o2"; mkdir -p "$TMP/o2/app" "$TMP/o2/backend"
cat > "$TMP/o2/workspace.yml" <<'YML'
name: Demo2
shape: monorepo
trunk: main
repos:
  app: { path: app, role: release-anchor }
  backend: { path: backend, role: service }
release:
  adapter: flutter-shorebird
  anchor_file: app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/services/scorer]
contracts:
  - name: promo
    paths: { app: lib/features/promo, backend: promo }
YML
printf 'name: demo\nversion: 1.0.0+1\n' > "$TMP/o2/app/pubspec.yaml"
git -C "$TMP/o2" add -A; git -C "$TMP/o2" commit -qm "workspace"
export WORKSPACE_ROOT="$TMP/o2"
git clone -q "$TMP/o2" "$TMP/o2-origin" --bare
git -C "$TMP/o2" remote add origin "$TMP/o2-origin"
git -C "$TMP/o2" fetch -q origin
out="$(cd "$TMP/o2/app" && bash "$KIT/bin/contract-check" 2>&1)"; rc=$?
printf '%s' "$out" | grep -q 'no changes against origin/main' && t_ok "mono: clean repo says so" || t_bad "mono clean" "no changes" "$out"
is "mono: clean repo exits 0" "0" "$rc"

finish
