#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
make_multi "$TMP/m"; R="$TMP/m/my-app"; B="$TMP/m/my-be"
git -C "$R" checkout -q develop
c=$(commit_file "$R" lib/features/x.dart "feat(x): thing")
export WORKSPACE_ROOT="$TMP/m"
echo "release-add"
out="$(bash "$KIT/bin/release-add" --dry-run | strip_ansi)"
printf '%s' "$out" | grep -q '^Dry run' && t_ok "dry run says so" || t_bad "dry run says so" "Dry run" "$out"
[ -f "$TMP/m/releases/UNRELEASED.md" ] && t_bad "dry run writes nothing" "no file" "file" || t_ok "dry run writes nothing"
bash "$KIT/bin/release-add" >/dev/null
source "$KIT/lib/release-common.sh"
is "one row recorded" "1" "$(unreleased_count)"
is "row is OTA feat" "| 1 | 🟢 OTA | feat | thing | \`$(git -C "$R" rev-parse --short=12 HEAD)\` | — | no |" "$(unreleased_rows)"
raw_out="$(bash "$KIT/bin/release-add" 2>&1)"
add_rc=$?
out="$(printf '%s' "$raw_out" | strip_ansi)"
printf '%s' "$out" | grep -q 'already in UNRELEASED.md' && t_ok "idempotent" || t_bad "idempotent" "already" "$out"
is "idempotent re-run exits 0" "0" "$add_rc"
bc=$(commit_file "$B" src/x.ts "be side")
c2=$(commit_file "$R" lib/core/services/api_service.dart "fix: api")
bash "$KIT/bin/release-add" "$c2" --be "$bc" >/dev/null
is "paired row is coupled yes with the BE short" "yes" "$(unreleased_rows | tail -1 | awk -F'|' '{gsub(/ /,"",$8); print $8}')"
c3=$(commit_file "$R" lib/core/services/api_service.dart "fix: api again")
out="$(bash "$KIT/bin/release-add" "$c3" 2>&1 | strip_ansi)"
printf '%s' "$out" | grep -q 'BE-contract consumer' && t_ok "coupling warning" || t_bad "coupling warning" "warn" "$out"
is "unpaired contract touch is maybe" "maybe" "$(unreleased_rows | tail -1 | awk -F'|' '{gsub(/ /,"",$8); print $8}')"
is "status prints the rows" "3" "$(bash "$KIT/bin/release-status" | grep -c '^|')"

echo "release-add: --paired repo: prefix"
c4=$(commit_file "$R" lib/features/y.dart "feat(y): another")
bash "$KIT/bin/release-add" "$c4" --paired "backend:$bc" >/dev/null
is "explicit repo: prefix names the backend and records its short hash" \
  "\`$(git -C "$B" rev-parse --short=12 "$bc")\`" \
  "$(unreleased_rows | tail -1 | awk -F'|' '{gsub(/^ +| +$/,"",$7); print $7}')"

echo "release-add: two service repos force the repo: form"
cat > "$TMP/m/workspace.yml" <<EOF
name: Demo
shape: multi-repo
repos:
  app: { path: my-app, trunk: develop, role: release-anchor, mirror: main }
  backend: { path: my-be, trunk: main, role: service }
  worker: { path: my-be, trunk: main, role: service }
release:
  adapter: flutter-shorebird
  anchor_file: my-app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/core/services/api_service]
EOF
c5=$(commit_file "$R" lib/features/z.dart "feat(z): yet another")
# release-common.sh (sourced above) sets -e in this shell too; this call is
# expected to die (nonzero), so keep the bare assignment from aborting the test.
out="$(bash "$KIT/bin/release-add" "$c5" --be "$bc" 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -q -- '--paired <repo>:<commit>' && t_ok "ambiguous service repo names the repo: form" || t_bad "ambiguous service repo names the repo: form" "--paired <repo>:<commit>" "$out"
# restore the single-service workspace.yml for the rest of the tests
make_multi "$TMP/m2"; cp "$TMP/m2/workspace.yml" "$TMP/m/workspace.yml"

echo "release-add: error paths"
out="$(bash "$KIT/bin/release-add" --nope 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -q 'Unknown flag' && t_ok "unknown flag dies" || t_bad "unknown flag dies" "Unknown flag" "$out"
out="$(bash "$KIT/bin/release-add" not-a-commit 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -q 'Not a commit in my-app' && t_ok "bad commit-ish dies naming the repo label" || t_bad "bad commit-ish dies naming the repo label" "Not a commit in my-app" "$out"

echo "release-add: pipe in the commit summary"
c6=$(commit_file "$R" lib/features/pipe.dart 'fix: a | b')
bash "$KIT/bin/release-add" "$c6" >/dev/null
row="$(unreleased_rows | tail -1)"
h6="$(git -C "$R" rev-parse --short=12 "$c6")"
is "the recorded row still resolves the right commit" "$h6" "$(unreleased_commit_for "$(printf '%s' "$row" | awk -F'|' '{gsub(/ /,"",$2); print $2}')")"
is "the row still has the right number of columns" "9" "$(printf '%s' "$row" | awk -F'|' '{print NF}')"

echo "release-status"
make_multi "$TMP/s"
out="$(WORKSPACE_ROOT="$TMP/s" bash "$KIT/bin/release-status")"
is "empty inventory prints nothing" "" "$out"
WORKSPACE_ROOT="$TMP/s" bash "$KIT/bin/release-status" >/dev/null
status_rc=$?
is "release-status exits 0 on an empty inventory" "0" "$status_rc"

echo "monorepo"
make_mono "$TMP/o"; export WORKSPACE_ROOT="$TMP/o"
c=$(commit_file "$TMP/o" app/lib/a.dart "chore: mono")
bash "$KIT/bin/release-add" "$c" >/dev/null
is "records in the monorepo" "1" "$(grep -c '^| 1 ' "$TMP/o/releases/UNRELEASED.md")"
c7=$(commit_file "$TMP/o" backend/src/y.ts "chore: backend-only file")
bash "$KIT/bin/release-add" "$c7" >/dev/null
is "a commit touching another role's directory still records" "2" "$(grep -c '^| [0-9]' "$TMP/o/releases/UNRELEASED.md")"

finish
