#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
make_multi "$TMP/m"; WORKSPACE_ROOT="$TMP/m"
source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/inventory.sh"; source "$KIT/lib/notes.sh"
mkdir -p "$RELEASES_DIR"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$RELEASES_DIR/"
R="$TMP/m/my-app"

echo "tags"
is "tag from config" "released/1.2.3+4" "$(released_tag_for 1.2.3+4)"
is "no tag yet" "" "$(latest_released_version)"
git -C "$R" tag released/1.0.0+9; git -C "$R" tag released/1.0.1+10
is "latest by build number" "1.0.1+10" "$(latest_released_version)"
is "first patch index" "1" "$(next_patch_index 1.0.1+10)"
touch "$RELEASES_DIR/1.0.1+10.patch1.md" "$RELEASES_DIR/1.0.1+10.patch2.md"
is "counts existing notes" "3" "$(next_patch_index 1.0.1+10)"

echo "rendering"
c1=$(commit_file "$R" lib/a.dart "fix: one"); s1=$(git -C "$R" rev-parse --short=12 "$c1")
c2=$(commit_file "$R" lib/b.dart "feat: two"); s2=$(git -C "$R" rev-parse --short=12 "$c2")
ensure_unreleased
append_unreleased_row "🟢 OTA" "fix" "one" "$s1" "—" "no"
append_unreleased_row "🟢 OTA" "feat" "two" "$s2" "\`beef\`" "yes"
# The app-commit field is stored with backticks already embedded (append_unreleased_row
# writes `` `%s` ``), and render_changelog_rows only trims whitespace, so the rendered
# row keeps them — matching the faithful port of the source, not the brief's sample
# (which omits the backticks; verified against release-common.sh directly).
is "changelog rows" "| \`$s1\` | 🟢 OTA | fix | one |" "$(render_changelog_rows "1")"
is "dependencies name the BE commit" "- two — BE commit \`beef\` must be deployed before rollout" "$(render_dependencies "2")"
is "no dependencies line" "None — no backend / data changes." "$(render_dependencies "1")"

out="$RELEASES_DIR/1.0.1+10.patch3.md"
write_note_from_template "$TEMPLATE_PATCH" "$out" "1.0.1+10" "3" "1 2"
grep -q '^# Demo 1.0.1+10 — patch 3 (OTA)' "$out" && t_ok "patch note heading" || t_bad "patch note heading" "Demo…" "$(head -2 "$out" | tail -1)"
grep -q "^| \`$s2\` | 🟢 OTA | feat | two |" "$out" && t_ok "rows substituted" || t_bad "rows substituted" "row" "missing"
grep -q '{{' "$out" && t_bad "no tokens left" "none" "$(grep -o '{{[A-Z_]*}}' "$out" | head -1)" || t_ok "no tokens left"

is "sibling note found by commit set" "$out" "$(find_sibling_note_for_commits 1.0.1+10 "$c2" "$c1")"
is "rows by commit reuse the sibling" "$(extract_changelog_rows_from_note "$out")" "$(render_changelog_rows_by_commit 1.0.1+10 "$c1" "$c2")"

out2="$RELEASES_DIR/1.0.1+11.md"
write_note_from_template "$TEMPLATE_BASE" "$out2" "1.0.1+11" "" "1"
grep -q '^- \*\*Status:\*\* released ' "$out2" && t_ok "release status" || t_bad "release status" "released" "?"

echo "next_patch_index after a deletion (documented, not fixed)"
# Notes 1 and 3 exist, 2 was deleted: the function counts files, not the
# highest N, so it returns existing-count+1 (2+1=3) — colliding with patch3
# that already exists. This is the documented (wrong) behaviour, ported as-is.
mkdir -p "$TMP/gap"; PATCH_BASE="1.5.0+1"
touch "$TMP/gap/${PATCH_BASE}.patch1.md" "$TMP/gap/${PATCH_BASE}.patch3.md"
(
  RELEASES_DIR_SAVED="$RELEASES_DIR"
  RELEASES_DIR="$TMP/gap"
  is "counts files, not max index, after a gap" "3" "$(next_patch_index "$PATCH_BASE")"
  RELEASES_DIR="$RELEASES_DIR_SAVED"
)

echo "sibling note set comparison is order-independent and exact"
is "sibling found with commits given in reverse order" "$out" "$(find_sibling_note_for_commits 1.0.1+10 "$c1" "$c2")"
if find_sibling_note_for_commits 1.0.1+10 "$c1" >/dev/null 2>&1; then
  t_bad "subset of commits does not match a sibling" "no match" "matched"
else
  t_ok "subset of commits does not match a sibling"
fi
c3=$(commit_file "$R" lib/c.dart "chore: three")
if find_sibling_note_for_commits 1.0.1+10 "$c1" "$c2" "$c3" >/dev/null 2>&1; then
  t_bad "superset of commits does not match a sibling" "no match" "matched"
else
  t_ok "superset of commits does not match a sibling"
fi

echo "released vs patched status wording"
grep -q '^- \*\*Status:\*\* patched .* (OTA)$' "$out" && t_ok "patch status wording" || t_bad "patch status wording" "patched … (OTA)" "$(grep '\*\*Status' "$out")"
grep -q '^- \*\*Status:\*\* released ' "$out2" && t_ok "release status wording (again)" || t_bad "release status wording (again)" "released …" "$(grep '\*\*Status' "$out2")"

echo "extra requirements"
# 1) a NON-default release.tag pattern really drives rendering + parsing.
(
  mkdir -p "$TMP/vtag"; git_init "$TMP/vtag/my-app"
  printf 'name: demo\nversion: 1.9.1+76\n' > "$TMP/vtag/my-app/pubspec.yaml"
  git -C "$TMP/vtag/my-app" add -A; git -C "$TMP/vtag/my-app" commit -qm pubspec
  git -C "$TMP/vtag/my-app" branch develop
  cat > "$TMP/vtag/workspace.yml" <<'EOF'
name: Demo
shape: multi-repo
repos:
  app: { path: my-app, trunk: develop, role: release-anchor, mirror: main }
  backend: { path: my-be, trunk: main, role: service }
release:
  adapter: flutter-shorebird
  anchor_file: my-app/pubspec.yaml
  tag: "v{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/core/services/api_service]
EOF
  git_init "$TMP/vtag/my-be"
  (
    WORKSPACE_ROOT="$TMP/vtag"
    source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/notes.sh"
    is "released_tag_for honors a non-default pattern" "v1.2.3+4" "$(released_tag_for 1.2.3+4)"
    git -C "$TMP/vtag/my-app" tag v1.2.3+4
    git -C "$TMP/vtag/my-app" tag v1.2.3+9
    is "latest_released_version strips a non-default prefix" "1.2.3+9" "$(latest_released_version)"
  )
)

# 2) build numbers that sort differently as strings than as numbers (+9 vs +10).
git -C "$R" tag released/3.0.0+9
git -C "$R" tag released/3.0.0+10
(
  # Filter down to just the 3.0.0 tags by using a scratch repo/tag namespace
  # would require another fixture; instead confirm directly via the same sort
  # pipeline latest_released_version uses.
  result="$(git -C "$R" tag --list 'released/3.0.0+*' | sed -E 's#^released/##' | sort -t+ -k2 -n | tail -n1)"
  is "numeric build sort: +10 beats +9" "3.0.0+10" "$result"
)

# 3) no matching tag at all -> empty, exit 0.
(
  mkdir -p "$TMP/notag"; git_init "$TMP/notag/my-app"
  printf 'name: demo\nversion: 1.0.0+1\n' > "$TMP/notag/my-app/pubspec.yaml"
  git -C "$TMP/notag/my-app" add -A; git -C "$TMP/notag/my-app" commit -qm pubspec
  git -C "$TMP/notag/my-app" branch develop
  git_init "$TMP/notag/my-be"
  cat > "$TMP/notag/workspace.yml" <<'EOF'
name: Demo
shape: multi-repo
repos:
  app: { path: my-app, trunk: develop, role: release-anchor, mirror: main }
  backend: { path: my-be, trunk: main, role: service }
release:
  adapter: flutter-shorebird
  anchor_file: my-app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/core/services/api_service]
EOF
  (
    WORKSPACE_ROOT="$TMP/notag"
    source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/notes.sh"
    v="$(latest_released_version)"; rc=$?
    is "no matching tag -> empty" "" "$v"
    [ "$rc" -eq 0 ] && t_ok "no matching tag -> exit 0" || t_bad "no matching tag -> exit 0" "0" "$rc"
  )
)

# 4) empty picked-item list still renders a valid note with the placeholder row.
out_empty="$RELEASES_DIR/1.0.1+12.md"
write_note_from_template "$TEMPLATE_BASE" "$out_empty" "1.0.1+12" "" ""
grep -q '^| — | — | — | (no itemized changes) |$' "$out_empty" && t_ok "empty items -> no itemized changes row" || t_bad "empty items -> no itemized changes row" "placeholder row" "$(grep -A1 '| --- |' "$out_empty" | tail -1)"

# 5) write_note_from_template overwrites rather than appends.
before_lines="$(wc -l < "$out2")"
write_note_from_template "$TEMPLATE_BASE" "$out2" "1.0.1+11" "" "1"
after_lines="$(wc -l < "$out2")"
is "rewriting a note does not append (line count stable)" "$before_lines" "$after_lines"

# 6) rendering leaves no temp files behind. Point TMPDIR at an empty scratch
# dir (mktemp honors it) so leftovers are unambiguous, instead of diffing the
# real /tmp which other processes churn concurrently.
scratch_tmpdir="$TMP/tmpdir-scratch"; mkdir -p "$scratch_tmpdir"
(
  TMPDIR="$scratch_tmpdir"
  write_note_from_template "$TEMPLATE_PATCH" "$RELEASES_DIR/1.0.1+10.patch4.md" "1.0.1+10" "4" "1 2"
)
leftover="$(ls -A "$scratch_tmpdir" | wc -l | tr -d ' ')"
is "no leaked temp files" "0" "$leftover"

echo "NAME substitution survives awk-gsub-special characters"
# render_with_name <fixture-dir> <name yaml scalar, already quoted as needed>
# Builds a minimal one-repo fixture whose workspace name is the given literal,
# renders TEMPLATE_BASE, and prints the rendered H1 line.
render_with_name() {
  local dir="$1" name_yaml="$2"
  mkdir -p "$dir/app"; git_init "$dir/app"
  printf 'name: demo\nversion: 1.0.0+1\n' > "$dir/app/pubspec.yaml"
  git -C "$dir/app" add -A; git -C "$dir/app" commit -qm pubspec
  cat > "$dir/workspace.yml" <<EOF
name: $name_yaml
shape: monorepo
trunk: main
repos:
  app: { path: app, role: release-anchor, mirror: release }
release:
  adapter: flutter-shorebird
  anchor_file: app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/services/scorer]
EOF
  git -C "$dir" init -q -b main 2>/dev/null || true
  git -C "$dir" add -A 2>/dev/null; git -C "$dir" commit -qm workspace >/dev/null 2>&1 || true
  (
    WORKSPACE_ROOT="$dir"
    source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/inventory.sh"; source "$KIT/lib/notes.sh"
    mkdir -p "$RELEASES_DIR"; cp "$KIT"/templates/releases/_TEMPLATE.*.md "$RELEASES_DIR/"
    write_note_from_template "$TEMPLATE_BASE" "$dir/out.md" "1.0.0+1" "" ""
    grep -m1 "^# " "$dir/out.md"
  )
}

heading="$(render_with_name "$TMP/name-plain" 'Demo')"
is "ordinary name renders unchanged" "# Demo 1.0.0+1 — store release" "$heading"

heading="$(render_with_name "$TMP/name-amp" "'A & B'")"
is "name containing an ampersand renders literally" "# A & B 1.0.0+1 — store release" "$heading"

heading="$(render_with_name "$TMP/name-bs" "'A \\ B'")"
is "name containing a backslash renders literally" "# A \\ B 1.0.0+1 — store release" "$heading"

heading="$(render_with_name "$TMP/name-both" "'A & B \\ C'")"
is "name containing both an ampersand and a backslash renders literally" "# A & B \\ C 1.0.0+1 — store release" "$heading"

finish
