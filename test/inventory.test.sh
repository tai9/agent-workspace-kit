#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
make_multi "$TMP/m"; WORKSPACE_ROOT="$TMP/m"
source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/inventory.sh"
echo "Inventory bookkeeping"
is "releases dir sits at the root" "$TMP/m/releases" "$RELEASES_DIR"
ensure_unreleased
is "starts empty"  "0" "$(unreleased_count)"
grep -q '^# Unreleased — Demo app' "$UNRELEASED_FILE" && t_ok "heading uses the workspace name" || t_bad "heading uses the workspace name" "Demo" "$(head -1 "$UNRELEASED_FILE")"
grep -q 'merged into `develop`' "$UNRELEASED_FILE" && t_ok "intro names the anchor trunk" || t_bad "intro names the anchor trunk" "develop" "?"
append_unreleased_row "🟢 OTA" "fix" "first item"  "aaaaaaaaaaaa" "—" "no"
append_unreleased_row "🔴 Store" "feat" "second item" "bbbbbbbbbbbb" "—" "no"
append_unreleased_row "🟢 OTA" "chore" "third item" "cccccccccccc" "—" "no"
is "counts every row"  "3" "$(unreleased_count)"
is "numbers rows in order" "1 2 3" "$(unreleased_rows | awk -F'|' '{gsub(/ /,"",$2); printf "%s ", $2}' | sed 's/ $//')"
unreleased_has_commit "bbbbbbbbbbbb" && t_ok "finds a recorded commit" || t_bad "finds a recorded commit" "found" "not found"
unreleased_has_commit "dddddddddddd" && t_bad "does not invent one" "not found" "found" || t_ok "does not invent an unrecorded commit"
is "commit for item 2" "bbbbbbbbbbbb" "$(unreleased_commit_for 2)"
is "channel for item 2" "STORE" "$(unreleased_channel_for 2)"
is "channel for item 1" "OTA" "$(unreleased_channel_for 1)"
remove_unreleased_rows "2"
is "removing a row drops it"      "2" "$(unreleased_count)"
is "and renumbers what is left"   "1 2" "$(unreleased_rows | awk -F'|' '{gsub(/ /,"",$2); printf "%s ", $2}' | sed 's/ $//')"
unreleased_has_commit "bbbbbbbbbbbb" && t_bad "the removed commit is gone" "not found" "found" || t_ok "the removed commit is gone"
unreleased_has_commit "cccccccccccc" && t_ok "the survivors are untouched" || t_bad "the survivors are untouched" "found" "not found"
grep -q '^_Last updated: [0-9]' "$UNRELEASED_FILE" && t_ok "stamp updated" || t_bad "stamp updated" "date" "never"

echo "Inventory edge cases"

# Rebuild a fresh inventory for the removal-edge-case scenarios.
rm -f "$UNRELEASED_FILE"
ensure_unreleased
append_unreleased_row "🟢 OTA" "fix" "one"   "111111111111" "—" "no"
append_unreleased_row "🟢 OTA" "fix" "two"   "222222222222" "—" "no"
append_unreleased_row "🟢 OTA" "fix" "three" "333333333333" "—" "no"
append_unreleased_row "🟢 OTA" "fix" "four"  "444444444444" "—" "no"

remove_unreleased_rows "1 3"
is "removing several rows drops exactly those" "2" "$(unreleased_count)"
is "and renumbers the survivors" "1 2" "$(unreleased_rows | awk -F'|' '{gsub(/ /,"",$2); printf "%s ", $2}' | sed 's/ $//')"
unreleased_has_commit "222222222222" && t_ok "survivor two remains" || t_bad "survivor two remains" "found" "not found"
unreleased_has_commit "444444444444" && t_ok "survivor four remains" || t_bad "survivor four remains" "found" "not found"

before_rows="$(unreleased_rows)"
remove_unreleased_rows "99"
is "removing a non-existent row changes nothing" "$before_rows" "$(unreleased_rows)"

remove_unreleased_rows "1 2"
is "removing all rows leaves an empty inventory" "0" "$(unreleased_count)"
append_unreleased_row "🟢 OTA" "fix" "fresh after empty" "555555555555" "—" "no"
is "append still works after emptying" "1" "$(unreleased_count)"
is "numbering restarts at 1" "1" "$(unreleased_rows | awk -F'|' '{gsub(/ /,"",$2); printf "%s ", $2}' | sed 's/ $//')"

# A summary containing a markdown pipe already escaped by the caller (as
# release-add.sh does: SUMMARY="${SUMMARY//|/\\|}") must round-trip as a
# single table row: the escape only protects markdown rendering, it is not
# stripped or reinterpreted by append/read, and the row/marker structure
# around it is untouched. (Field-position lookups such as
# unreleased_commit_for are not pipe-safe for this one row — matching the
# original VS behavior verbatim; not something this port changes.)
rm -f "$UNRELEASED_FILE"
ensure_unreleased
append_unreleased_row "🟢 OTA" "fix" "summary with an escaped pipe \\| in it" "666666666666" "—" "no"
is "escaped-pipe row round-trips as a single row" "1" "$(unreleased_count)"
row_line_count="$(unreleased_rows | grep -c '^|' || true)"
is "escaped-pipe row is still one physical line" "1" "$row_line_count"
unreleased_rows | grep -qF 'escaped pipe | in it' && t_ok "the escaped pipe text survives verbatim" || t_bad "the escaped pipe text survives verbatim" 'escaped pipe | in it' "$(unreleased_rows)"

before_file="$(cat "$UNRELEASED_FILE")"
ensure_unreleased
is "ensure_unreleased is idempotent" "$before_file" "$(cat "$UNRELEASED_FILE")"

is "commit lookup for missing item is empty" "" "$(unreleased_commit_for 42)"
unreleased_commit_for 42 >/dev/null
is "commit lookup for missing item exits 0" "0" "$?"
is "channel lookup for missing item is empty" "" "$(unreleased_channel_for 42)"
unreleased_channel_for 42 >/dev/null
is "channel lookup for missing item exits 0" "0" "$?"

echo "Inventory in a monorepo"
make_mono "$TMP/o"; WORKSPACE_ROOT="$TMP/o"
source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/inventory.sh"
ensure_unreleased
grep -q 'merged into `main`' "$UNRELEASED_FILE" && t_ok "monorepo intro names its own trunk" || t_bad "monorepo intro names its own trunk" "main" "?"

echo "The inventory's shape comes from the kit template, not a second copy"

# The heredoc that used to live in ensure_unreleased is gone: what a workspace
# that never ran `init` gets must be what `init` would have written, or the
# file drifts from the tooling that parses it.
make_multi "$TMP/tpl"; WORKSPACE_ROOT="$TMP/tpl"
source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/inventory.sh"
ensure_unreleased
expected="$(sed -e 's/{{NAME}}/Demo/g' -e 's/{{TRUNK}}/develop/g' "$KIT/templates/releases/UNRELEASED.md")"
is "seeded byte-for-byte from the template" "$expected" "$(cat "$UNRELEASED_FILE")"
grep -qF '{{' "$UNRELEASED_FILE" && t_bad "no token left unsubstituted" "none" "$(grep -F '{{' "$UNRELEASED_FILE")" || t_ok "no token left unsubstituted"
for m in 'STATE:START' 'STATE:END' 'ITEMS:START' 'ITEMS:END'; do
  grep -qF "<!-- $m -->" "$UNRELEASED_FILE" && t_ok "carries the $m marker" || t_bad "$m marker" "present" "missing"
done
is "the template stays short enough for the doctor" "1" "$([ "$(wc -l < "$KIT/templates/releases/UNRELEASED.md")" -le 60 ] && echo 1 || echo 0)"

echo "A workspace name is substituted literally"

# Both characters below have bitten this codebase before: `&` is "the matched
# text" to awk's gsub and to bash's patsub_replacement, and awk -v decodes
# backslash escapes in what it is handed.
make_multi "$TMP/amp"; WORKSPACE_ROOT="$TMP/amp"
sed -i.bak '1s/.*/name: Pen \& Pad \\n Co/' "$TMP/amp/workspace.yml"
source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/inventory.sh"
ensure_unreleased
is "an & and a backslash survive the heading" "# Unreleased — Pen & Pad \\n Co app" "$(head -1 "$UNRELEASED_FILE")"

finish
