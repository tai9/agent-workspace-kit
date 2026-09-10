#!/usr/bin/env bash
# Release-note rendering: the released tag, OTA patch numbering, and turning
# an inventory (or a sibling note's already-rendered content) into markdown
# via templates/releases/_TEMPLATE.{base,patch}.md.
# Ported from the original mobile-app release tooling's shared release-note library.

# The consumer's own copies under releases/ (seeded from the kit's templates/
# by `init`; a consumer is expected to edit their note templates).
TEMPLATE_BASE="$RELEASES_DIR/_TEMPLATE.base.md"
TEMPLATE_PATCH="$RELEASES_DIR/_TEMPLATE.patch.md"

# --- Released tag ------------------------------------------------------------
# The live store base is tagged released/<version> in the app repo. patches
# stack on it.
released_tag_for() { printf '%s' "$(cfg_default release.tag 'released/{version}')" | sed "s/{version}/$1/"; }

latest_released_version() {
  anchor_git tag --list "$(released_tag_for '*')" \
    | sed -E "s#^$(released_tag_for '')##" \
    | sort -t+ -k2 -n \
    | tail -n1
}

# Next patch index for a base version: count existing <base>.patchN.md + 1.
next_patch_index() {
  local base="$1" n=0 f
  for f in "$RELEASES_DIR/$base".patch*.md; do
    [[ -e "$f" ]] || continue
    n=$((n + 1))
  done
  printf '%d' $((n + 1))
}

# --- Note rendering ----------------------------------------------------------
# Render markdown changelog rows for the given item numbers, pulled from the
# inventory: "| <app commit> | <channel> | <type> | <summary> |".
render_changelog_rows() {
  local picks=" $1 "
  unreleased_rows | awk -F'|' -v picks="$picks" '
    /^\|/ {
      num=$2; gsub(/ /,"",num)
      if (index(picks, " " num " ") > 0) {
        ch=$3; ty=$4; su=$5; ac=$6
        gsub(/^[ \t]+|[ \t]+$/,"",ch); gsub(/^[ \t]+|[ \t]+$/,"",ty)
        gsub(/^[ \t]+|[ \t]+$/,"",su); gsub(/^[ \t]+|[ \t]+$/,"",ac)
        printf "| %s | %s | %s | %s |\n", ac, ch, ty, su
      }
    }'
}

# Render the "release dependencies" block for the given items: one bullet per
# coupled item naming the BE commit, or a "None" line.
render_dependencies() {
  local picks=" $1 " out
  out="$(unreleased_rows | awk -F'|' -v picks="$picks" '
    /^\|/ {
      num=$2; gsub(/ /,"",num)
      if (index(picks, " " num " ") > 0) {
        su=$5; bc=$7; co=$8
        gsub(/^[ \t]+|[ \t]+$/,"",su); gsub(/^[ \t]+|[ \t]+$/,"",bc); gsub(/^[ \t]+|[ \t]+$/,"",co)
        if (co ~ /yes|maybe/) printf "- %s — BE commit %s must be deployed before rollout\n", su, bc
      }
    }')"
  if [[ -n "$out" ]]; then printf '%s\n' "$out"; else printf 'None — no backend / data changes.\n'; fi
}

# --- Cross-platform "same batch, other platform" note reuse ------------------
# A patch batch is normally noted once, from UNRELEASED.md, and the rows are
# removed from the inventory on ship. Shipping the *identical* commit set to
# the other platform (e.g. iOS today, Android tomorrow, same items) runs
# release-cut.sh a second time with nothing left in UNRELEASED.md to resolve
# — the cherry-pick step already tolerates this (a commit already baked into
# the tag lands as an --empty=keep no-op), but note rendering has no inventory
# row left to read a summary/channel/dependency from. These functions recover
# that content from the sibling platform's already-written patch note instead
# of re-deriving it from a now-empty inventory.

# Extract just the data rows of the "## Changelog (internal)" table (the
# substituted {{CHANGELOG_ROWS}} content) from an already-written patch note.
extract_changelog_rows_from_note() {
  awk '
    /^\| --- \|/ { inrows = 1; next }
    /^### Release dependencies/ { inrows = 0 }
    inrows && /^\|/ { print }
  ' "$1"
}

# Extract the "### Release dependencies" block (the substituted
# {{DEPENDENCIES}} content) from an already-written patch note.
extract_dependencies_from_note() {
  awk '
    /^### Release dependencies/ { indeps = 1; next }
    /^### Verification/ { indeps = 0 }
    indeps { print }
  ' "$1" | sed '/^[[:space:]]*$/d'
}

# Find the prior patch note under releases/<base>.patch*.md whose Changelog
# table lists exactly the given full commit SHAs (as a set, order-independent
# — comparison is on the first 12 hex chars, matching how notes render them).
# Prints the matching file path and returns 0, or returns 1 if none matches.
find_sibling_note_for_commits() {
  local base="$1"; shift
  local wanted found f
  wanted="$(for c in "$@"; do anchor_git rev-parse --short=12 "$c"; done | sort)"
  for f in "$RELEASES_DIR/$base".patch*.md; do
    [[ -e "$f" ]] || continue
    found="$(extract_changelog_rows_from_note "$f" \
      | awk -F'|' '{ gsub(/[ \t`]/, "", $2); print $2 }' | sort)"
    if [[ "$found" == "$wanted" ]]; then
      printf '%s' "$f"
      return 0
    fi
  done
  return 1
}

# Changelog rows for a commit list, reusing a sibling note if one matches this
# exact commit set, else deriving minimal rows straight from `git log` (no
# channel/type/BE-dependency metadata exists outside UNRELEASED.md, so the
# fallback rows say so explicitly rather than guessing).
render_changelog_rows_by_commit() {
  local base="$1"; shift
  local sib c short subj
  if sib="$(find_sibling_note_for_commits "$base" "$@")"; then
    extract_changelog_rows_from_note "$sib"
    return 0
  fi
  for c in "$@"; do
    short="$(anchor_git rev-parse --short=12 "$c")"
    subj="$(anchor_git log -1 --format=%s "$c")"
    printf '| `%s` | ? | ? | %s _(no sibling patch note found — channel/type/dependency metadata unavailable outside UNRELEASED.md; verify manually)_ |\n' "$short" "$subj"
  done
}

# Dependencies block for a commit list — same sibling-reuse strategy as
# render_changelog_rows_by_commit.
render_dependencies_by_commit() {
  local base="$1"; shift
  local sib
  if sib="$(find_sibling_note_for_commits "$base" "$@")"; then
    extract_dependencies_from_note "$sib"
    return 0
  fi
  printf 'Unknown — no sibling patch note found for this exact commit set; verify manually whether any coupled BE commit must be live before rollout.\n'
}

# Same as write_note_from_template, but for the --commits (not --items) patch
# path: sources CHANGELOG_ROWS/DEPENDENCIES via the sibling-note helpers above
# instead of reading (now possibly-empty) UNRELEASED.md rows.
#   write_note_from_template_by_commits <template> <out> <version> <patch-index> <base> <commit...>
write_note_from_template_by_commits() {
  local tpl="$1" out="$2" version="$3" pidx="$4" base="$5"; shift 5
  [[ -f "$tpl" ]] || die "Template not found: $tpl"
  local dt status cl_file dep_file name
  dt="$(today)"
  status="patched $dt (OTA)"
  name="$(cfg_default name Workspace)"
  # awk's -v assignment itself decodes C-style escapes in the value (so a lone
  # "\" in a free-form name would otherwise vanish before the awk program ever
  # sees it) — double every backslash here so -v's decoding round-trips it.
  name="${name//\\/\\\\}"
  cl_file="$(mktemp)"; dep_file="$(mktemp)"
  render_changelog_rows_by_commit "$base" "$@" > "$cl_file"
  [[ -s "$cl_file" ]] || printf '| — | — | — | (no itemized changes) |\n' > "$cl_file"
  render_dependencies_by_commit "$base" "$@" > "$dep_file"
  awk -v version="$version" -v dt="$dt" -v status="$status" -v pidx="$pidx" -v name="$name" \
      -v clf="$cl_file" -v depf="$dep_file" '
    {
      line=$0
      gsub(/\{\{VERSION\}\}/, version, line)
      gsub(/\{\{DATE\}\}/, dt, line)
      gsub(/\{\{STATUS\}\}/, status, line)
      gsub(/\{\{PATCH_INDEX\}\}/, pidx, line)
      # NAME is handled by literal concatenation, not gsub(re, name, line): unlike
      # VERSION/DATE/STATUS/PATCH_INDEX (constrained formats that cannot contain
      # "&" or "\\"), the workspace name is free-form config a user types, and
      # gsub treats "&" in its replacement argument as "insert the match" — a
      # name like "A & B" would silently corrupt the heading.
      if (index(line, "{{NAME}}") > 0) {
        out = ""; rest = line
        while ((i = index(rest, "{{NAME}}")) > 0) {
          out = out substr(rest, 1, i - 1) name
          rest = substr(rest, i + 8)
        }
        line = out rest
      }
      if (line ~ /^[[:space:]]*\{\{CHANGELOG_ROWS\}\}[[:space:]]*$/) { while ((getline l < clf)  > 0) print l; close(clf);  next }
      if (line ~ /^[[:space:]]*\{\{DEPENDENCIES\}\}[[:space:]]*$/)   { while ((getline l < depf) > 0) print l; close(depf); next }
      print line
    }' "$tpl" > "$out"
  rm -f "$cl_file" "$dep_file"
}

# Render a release/patch note from a template, substituting tokens and the
# multi-line CHANGELOG_ROWS / DEPENDENCIES blocks.
#   write_note_from_template <template> <out> <version> <patch-index|""> <items>
write_note_from_template() {
  local tpl="$1" out="$2" version="$3" pidx="$4" items="$5"
  [[ -f "$tpl" ]] || die "Template not found: $tpl"
  local dt status cl_file dep_file name
  dt="$(today)"
  if [[ -n "$pidx" ]]; then status="patched $dt (OTA)"; else status="released $dt"; fi
  name="$(cfg_default name Workspace)"
  # awk's -v assignment itself decodes C-style escapes in the value (so a lone
  # "\" in a free-form name would otherwise vanish before the awk program ever
  # sees it) — double every backslash here so -v's decoding round-trips it.
  name="${name//\\/\\\\}"
  # Multi-line blocks go through temp files — awk -v cannot carry newlines.
  cl_file="$(mktemp)"; dep_file="$(mktemp)"
  render_changelog_rows "$items" > "$cl_file"
  [[ -s "$cl_file" ]] || printf '| — | — | — | (no itemized changes) |\n' > "$cl_file"
  render_dependencies "$items" > "$dep_file"
  awk -v version="$version" -v dt="$dt" -v status="$status" -v pidx="$pidx" -v name="$name" \
      -v clf="$cl_file" -v depf="$dep_file" '
    {
      line=$0
      gsub(/\{\{VERSION\}\}/, version, line)
      gsub(/\{\{DATE\}\}/, dt, line)
      gsub(/\{\{STATUS\}\}/, status, line)
      gsub(/\{\{PATCH_INDEX\}\}/, pidx, line)
      # NAME is handled by literal concatenation, not gsub(re, name, line): unlike
      # VERSION/DATE/STATUS/PATCH_INDEX (constrained formats that cannot contain
      # "&" or "\\"), the workspace name is free-form config a user types, and
      # gsub treats "&" in its replacement argument as "insert the match" — a
      # name like "A & B" would silently corrupt the heading.
      if (index(line, "{{NAME}}") > 0) {
        out = ""; rest = line
        while ((i = index(rest, "{{NAME}}")) > 0) {
          out = out substr(rest, 1, i - 1) name
          rest = substr(rest, i + 8)
        }
        line = out rest
      }
      if (line ~ /^[[:space:]]*\{\{CHANGELOG_ROWS\}\}[[:space:]]*$/) { while ((getline l < clf)  > 0) print l; close(clf);  next }
      if (line ~ /^[[:space:]]*\{\{DEPENDENCIES\}\}[[:space:]]*$/)   { while ((getline l < depf) > 0) print l; close(depf); next }
      print line
    }' "$tpl" > "$out"
  rm -f "$cl_file" "$dep_file"
}
