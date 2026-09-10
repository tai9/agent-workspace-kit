#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- brief's own dry-run sketch --------------------------------------------
make_multi "$TMP/m"; export WORKSPACE_ROOT="$TMP/m"; R="$TMP/m/my-app"
mkdir -p "$TMP/m/releases"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$TMP/m/releases/"
git -C "$R" checkout -q develop; git -C "$R" tag released/1.9.1+76
c1=$(commit_file "$R" lib/a.dart "fix: a"); c2=$(commit_file "$R" android/x "feat: native")
bash "$KIT/bin/release-add" "$c1" >/dev/null; bash "$KIT/bin/release-add" "$c2" >/dev/null
echo "patch"
out="$(bash "$KIT/bin/release-cut" patch production ios --items "1" --dry-run | strip_ansi)"
printf '%s' "$out" | grep -q 'base       : 1.9.1+76 (tag released/1.9.1+76)' && t_ok "resolves the base" || t_bad "base" "1.9.1+76" "$out"
printf '%s' "$out" | grep -q "commits    : $c1" && t_ok "resolves the commit" || t_bad "commit" "$c1" "$out"
printf '%s' "$out" | grep -q 'note file  : releases/1.9.1+76.patch1.md' && t_ok "note path relative to the root" || t_bad "note" "releases/…" "$out"
printf '%s' "$out" | grep -q 'Dry run — stopping' && t_ok "stops" || t_bad "stops" "Dry run" "$out"
bash "$KIT/bin/release-cut" patch production ios --items "2" --dry-run >/dev/null 2>&1 && t_bad "refuses a Store item" "1" "0" || t_ok "refuses a Store item"
bash "$KIT/bin/release-cut" patch production both --items "1" --dry-run >/dev/null 2>&1 && t_bad "patch platform must be single" "1" "0" || t_ok "patch platform must be single"
[ -d "$TMP/m/.release-worktrees" ] && t_bad "dry run makes no worktree" "none" "dir" || t_ok "dry run makes no worktree"
echo "release"
out="$(bash "$KIT/bin/release-cut" release production both --dry-run | strip_ansi)"
printf '%s' "$out" | grep -q 'version    : 1.9.1+76 -> 1.9.1+77 (predicted' && t_ok "predicts the bump" || t_bad "predict" "1.9.1+77" "$out"
printf '%s' "$out" | grep -q 'items      : 1 2' && t_ok "defaults to all items" || t_bad "items" "1 2" "$out"
printf '%s' "$out" | grep -q 'will tag   : released/1.9.1+77 on develop after bump' && t_ok "tags on the trunk" || t_bad "tag line" "develop" "$out"
echo "monorepo"
make_mono "$TMP/o"; export WORKSPACE_ROOT="$TMP/o"; mkdir -p "$TMP/o/releases"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$TMP/o/releases/"
git -C "$TMP/o" tag released/1.0.0+6; c=$(commit_file "$TMP/o" app/lib/a.dart "fix: m"); bash "$KIT/bin/release-add" "$c" >/dev/null
out="$(bash "$KIT/bin/release-cut" patch production android --items 1 --dry-run | strip_ansi)"
printf '%s' "$out" | grep -q 'base       : 1.0.0+6' && t_ok "mono patch resolves" || t_bad "mono" "1.0.0+6" "$out"

# --- dry-run leaves absolutely no trace (requirement 3) --------------------
export WORKSPACE_ROOT="$TMP/m"
before_inv="$(cat "$TMP/m/releases/UNRELEASED.md")"
before_tags="$(git -C "$R" tag --list | sort)"
bash "$KIT/bin/release-cut" patch production ios --items "1" --dry-run >/dev/null
[ -d "$TMP/m/.release-worktrees" ] && t_bad "patch dry-run: no worktree dir" "none" "dir" || t_ok "patch dry-run: no worktree dir"
after_tags="$(git -C "$R" tag --list | sort)"
is "patch dry-run: no tag written" "$before_tags" "$after_tags"
[ -f "$TMP/m/releases/1.9.1+76.patch1.md" ] && t_bad "patch dry-run: no note written" "no file" "file" || t_ok "patch dry-run: no note written"
is "patch dry-run: inventory byte-identical" "$before_inv" "$(cat "$TMP/m/releases/UNRELEASED.md")"

bash "$KIT/bin/release-cut" release production both --dry-run >/dev/null
[ -d "$TMP/m/.release-worktrees" ] && t_bad "release dry-run: no worktree dir" "none" "dir" || t_ok "release dry-run: no worktree dir"
after_tags="$(git -C "$R" tag --list | sort)"
is "release dry-run: no tag written" "$before_tags" "$after_tags"
[ -f "$TMP/m/releases/1.9.1+77.md" ] && t_bad "release dry-run: no note written" "no file" "file" || t_ok "release dry-run: no note written"
is "release dry-run: inventory byte-identical" "$before_inv" "$(cat "$TMP/m/releases/UNRELEASED.md")"

# --- refusals (requirement 4) ------------------------------------------------
echo "refusals"
out="$(bash "$KIT/bin/release-cut" patch production ios --items 1 --commits "$c1" --dry-run 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -qF 'pass --items OR --commits, not both' && t_ok "refuses items+commits together" || t_bad "items+commits" "not both" "$out"
out="$(bash "$KIT/bin/release-cut" patch production ios --dry-run 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -qF 'patch needs --items' && t_ok "refuses neither items nor commits" || t_bad "neither" "patch needs" "$out"
out="$(bash "$KIT/bin/release-cut" release production bogus --dry-run 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -qF 'release platform must be ios|android|both' && t_ok "refuses an invalid release platform" || t_bad "invalid release platform" "must be ios" "$out"
out="$(bash "$KIT/bin/release-cut" patch production ios --items 99 --dry-run 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -qF 'Item #99 not found in UNRELEASED.md' && t_ok "refuses an unknown item number" || t_bad "unknown item" "not found" "$out"
out="$(bash "$KIT/bin/release-cut" patch production ios --items 1 --base 9.9.9+9 --dry-run 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -qF 'Tag released/9.9.9+9 not found.' && t_ok "refuses a --base naming a missing tag" || t_bad "missing --base tag" "not found" "$out"

make_multi "$TMP/notag"; export WORKSPACE_ROOT="$TMP/notag"; mkdir -p "$TMP/notag/releases"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$TMP/notag/releases/"
out="$(bash "$KIT/bin/release-cut" patch production ios --items 1 --dry-run 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -qF 'No released/* tag — cut a release before patching.' && t_ok "refuses patch with no released tag" || t_bad "no released tag" "cut a release before patching" "$out"
export WORKSPACE_ROOT="$TMP/m"

# --- real patch cut against a fake adapter (requirement 5) ------------------
echo "real patch cut"
make_multi "$TMP/p"; export WORKSPACE_ROOT="$TMP/p"; RP="$TMP/p/my-app"
mkdir -p "$TMP/p/releases"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$TMP/p/releases/"
git -C "$RP" checkout -q develop; git -C "$RP" tag released/1.9.1+76
pc=$(commit_file "$RP" lib/patchable.dart "fix: patchable thing")
bash "$KIT/bin/release-add" "$pc" >/dev/null
cat >> "$TMP/p/workspace.yml" <<EOF
  patch_cmd: 'pwd >> "$TMP/p/patch.log"; printf "env=%s platform=%s allow=%s\n" "\$ENV" "\$PLATFORM" "\$ALLOW_ASSET_DIFFS" >> "$TMP/p/patch.log"'
EOF
sed -i.bak 's/adapter: flutter-shorebird/adapter: generic-semver/' "$TMP/p/workspace.yml"; rm -f "$TMP/p/workspace.yml.bak"

before_head="$(git -C "$RP" rev-parse HEAD)"; before_branch="$(git -C "$RP" branch --show-current)"
bash "$KIT/bin/release-cut" patch production ios --items 1 >/dev/null
after_tags_dir=$([ -d "$TMP/p/.release-worktrees" ] && echo present || echo absent)
is "worktree base is removed after a real patch cut" "absent" "$([ -d "$TMP/p/.release-worktrees/patch-1.9.1+76-1" ] && echo present || echo absent)"
[ -f "$TMP/p/patch.log" ] && t_ok "patch_cmd ran" || t_bad "patch_cmd ran" "log file" "missing"
grep -q "$TMP/p/.release-worktrees" "$TMP/p/patch.log" 2>/dev/null && t_ok "patch_cmd ran inside the throwaway worktree, not the real checkout" || t_bad "patch_cmd cwd" ".release-worktrees" "$(cat "$TMP/p/patch.log" 2>/dev/null)"
grep -q 'env=production platform=ios allow=0' "$TMP/p/patch.log" 2>/dev/null && t_ok "patch_cmd received env/platform/allow-flag" || t_bad "patch_cmd env" "env=production platform=ios allow=0" "$(cat "$TMP/p/patch.log" 2>/dev/null)"
new_tip="$(git -C "$RP" rev-parse released/1.9.1+76)"
[ "$new_tip" != "$(git -C "$RP" rev-parse "$pc"^{})" ] || true
git -C "$RP" show "released/1.9.1+76:lib/patchable.dart" >/dev/null 2>&1 && t_ok "picked commit's file is cherry-picked onto the tag" || t_bad "cherry-picked file" "present at tag" "missing"
[ -f "$TMP/p/releases/1.9.1+76.patch1.md" ] && t_ok "patch note exists" || t_bad "patch note exists" "1.9.1+76.patch1.md" "missing"
grep -q '1.9.1+76' "$TMP/p/releases/1.9.1+76.patch1.md" && grep -q 'patch 1' "$TMP/p/releases/1.9.1+76.patch1.md" \
  && t_ok "patch note names the right base and index" || t_bad "patch note contents" "base 1.9.1+76, patch 1" "$(cat "$TMP/p/releases/1.9.1+76.patch1.md")"
is "picked item is gone from the inventory" "0" "$(grep -c '^| 1 ' "$TMP/p/releases/UNRELEASED.md" || true)"
is "the checkout's HEAD is unchanged" "$before_head" "$(git -C "$RP" rev-parse HEAD)"
is "the checkout's branch is unchanged" "$before_branch" "$(git -C "$RP" branch --show-current)"
is "the checkout's tree is clean" "" "$(git -C "$RP" status --porcelain)"
[ -d "$TMP/p/.release-worktrees" ] && [ -z "$(ls -A "$TMP/p/.release-worktrees" 2>/dev/null)" ] || [ ! -d "$TMP/p/.release-worktrees" ] \
  && t_ok "no leftover worktree directory" || t_bad "no leftover worktree directory" "empty/absent" "$(ls -A "$TMP/p/.release-worktrees" 2>/dev/null)"
git -C "$RP" branch --list 'release-patch-*' | grep -q . && t_bad "no leftover temp branch" "none" "$(git -C "$RP" branch --list 'release-patch-*')" || t_ok "no leftover temp branch"

# --- real release cut against a fake adapter (requirement 6) ----------------
echo "real release cut"
make_multi "$TMP/r"; export WORKSPACE_ROOT="$TMP/r"; RR="$TMP/r/my-app"
mkdir -p "$TMP/r/releases"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$TMP/r/releases/"
git -C "$RR" checkout -q develop
printf '1.9.1+76' > "$RR/VERSION"; git -C "$RR" add VERSION; git -C "$RR" commit -qm "add VERSION"
rc=$(commit_file "$RR" lib/releasable.dart "feat: releasable thing")
bash "$KIT/bin/release-add" "$rc" >/dev/null
cat >> "$TMP/r/workspace.yml" <<EOF
  release_cmd: 'printf "1.9.1+77" > VERSION; printf "env=%s platform=%s distribute=%s\n" "\$ENV" "\$PLATFORM" "\$DISTRIBUTE" >> "$TMP/r/release.log"'
EOF
sed -i.bak -e 's/adapter: flutter-shorebird/adapter: generic-semver/' -e 's#anchor_file: my-app/pubspec.yaml#anchor_file: my-app/VERSION#' "$TMP/r/workspace.yml"; rm -f "$TMP/r/workspace.yml.bak"

bash "$KIT/bin/release-cut" release production both >/dev/null
is "the real checkout's version file now holds the worktree's version" "1.9.1+77" "$(cat "$RR/VERSION")"
trunk_log="$(git -C "$RR" log --format=%s develop)"
printf '%s' "$trunk_log" | grep -q 'chore(release): bump to 1.9.1+77' && t_ok "a bump commit exists on the trunk" || t_bad "bump commit" "chore(release): bump to 1.9.1+77" "$trunk_log"
is "the released tag was created at the bump commit" "$(git -C "$RR" rev-parse develop)" "$(git -C "$RR" rev-parse released/1.9.1+77)"
[ -f "$TMP/r/releases/1.9.1+77.md" ] && t_ok "release note exists" || t_bad "release note exists" "1.9.1+77.md" "missing"
is "the inventory row was removed" "0" "$(grep -c '^| 1 ' "$TMP/r/releases/UNRELEASED.md" || true)"
[ -d "$TMP/r/.release-worktrees" ] && [ -z "$(ls -A "$TMP/r/.release-worktrees" 2>/dev/null)" ] || [ ! -d "$TMP/r/.release-worktrees" ] \
  && t_ok "no leftover worktree directory after release" || t_bad "no leftover worktree directory after release" "empty/absent" "$(ls -A "$TMP/r/.release-worktrees" 2>/dev/null)"

# --- real patch cut against a fake adapter, monorepo shape (requirement 2/5) -
echo "real patch cut: monorepo"
make_mono "$TMP/po"; export WORKSPACE_ROOT="$TMP/po"
mkdir -p "$TMP/po/releases"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$TMP/po/releases/"
git -C "$TMP/po" tag released/1.0.0+6
mc=$(commit_file "$TMP/po" app/lib/patchable.dart "fix: mono patchable")
bash "$KIT/bin/release-add" "$mc" >/dev/null
cat >> "$TMP/po/workspace.yml" <<EOF
  patch_cmd: 'pwd >> "$TMP/po/patch.log"'
EOF
sed -i.bak 's/adapter: flutter-shorebird/adapter: generic-semver/' "$TMP/po/workspace.yml"; rm -f "$TMP/po/workspace.yml.bak"
bash "$KIT/bin/release-cut" patch production android --items 1 >/dev/null
grep -q "$TMP/po/.release-worktrees" "$TMP/po/patch.log" 2>/dev/null && grep -q "/app$" "$TMP/po/patch.log" \
  && t_ok "monorepo: patch_cmd ran inside the worktree's anchor subdir" || t_bad "monorepo patch_cmd cwd" ".release-worktrees/.../app" "$(cat "$TMP/po/patch.log" 2>/dev/null)"
git -C "$TMP/po" show "released/1.0.0+6:app/lib/patchable.dart" >/dev/null 2>&1 && t_ok "monorepo: picked commit cherry-picked onto the tag" || t_bad "monorepo cherry-pick" "present at tag" "missing"
is "monorepo: picked item is gone from the inventory" "0" "$(grep -c '^| 1 ' "$TMP/po/releases/UNRELEASED.md" || true)"

finish
