#!/usr/bin/env bash
# The UNRELEASED.md inventory: one table row per merged-but-unshipped item.
# `/release add` appends a row after every squash-merge; `/release cut` moves
# the picked rows out into a versioned release note.
RELEASES_DIR="$WORKSPACE_ROOT/releases"
UNRELEASED_FILE="$RELEASES_DIR/UNRELEASED.md"

# Markers that delimit the machine-parsed item table inside UNRELEASED.md.
ITEMS_START="<!-- ITEMS:START -->"
ITEMS_END="<!-- ITEMS:END -->"

# --- UNRELEASED.md inventory -------------------------------------------------
ensure_unreleased() {
  [[ -f "$UNRELEASED_FILE" ]] && return 0
  mkdir -p "$RELEASES_DIR"
  cat > "$UNRELEASED_FILE" <<EOF
# Unreleased — $(cfg_default name Workspace) app

Items merged into \`$(anchor_trunk)\` but not yet shipped. \`/release add\` appends a row
here on each squash-merge; \`/release cut\` moves the picked rows out into a
versioned store note (\`<version>.md\`) or a patch note
(\`<live-version>.patchN.md\`). See \`RELEASE_PROCESS.md\`.

_Last updated: never_

| # | Channel | Type | Summary | App commit | BE commit | Coupled |
| - | ------- | ---- | ------- | ---------- | --------- | ------- |
$ITEMS_START
$ITEMS_END
EOF
}

# Print the raw item rows (between the markers), excluding the markers.
unreleased_rows() {
  ensure_unreleased
  awk -v s="$ITEMS_START" -v e="$ITEMS_END" '
    $0==s {flag=1; next} $0==e {flag=0} flag' "$UNRELEASED_FILE"
}

unreleased_count() { unreleased_rows | grep -c '^|' || true; }

# True if a commit short-hash already has a row (idempotency for release-add).
unreleased_has_commit() {
  local short="$1"
  unreleased_rows | grep -qF "\`$short\`"
}

# Rewrite the "_Last updated_" line in place.
touch_unreleased_stamp() {
  local tmp; tmp="$(mktemp)"
  sed -E "s/^_Last updated: .*_$/_Last updated: $(now_stamp)_/" "$UNRELEASED_FILE" > "$tmp"
  mv "$tmp" "$UNRELEASED_FILE"
}

# Append a fully-formed table row (the pipe-delimited string without leading #)
# just before the ITEMS_END marker, renumbering all rows afterwards.
append_unreleased_row() {
  local channel="$1" type="$2" summary="$3" app_commit="$4" be_commit="$5" coupled="$6"
  ensure_unreleased
  local tmp; tmp="$(mktemp)"
  awk -v e="$ITEMS_END" \
      -v ch="$channel" -v ty="$type" -v su="$summary" \
      -v ac="$app_commit" -v bc="$be_commit" -v co="$coupled" '
    $0==e { printf "| 0 | %s | %s | %s | `%s` | %s | %s |\n", ch, ty, su, ac, bc, co }
    { print }
  ' "$UNRELEASED_FILE" > "$tmp"
  mv "$tmp" "$UNRELEASED_FILE"
  renumber_unreleased
  touch_unreleased_stamp
}

# Renumber the "#" column of every item row 1..N in document order.
renumber_unreleased() {
  local tmp; tmp="$(mktemp)"
  awk -v s="$ITEMS_START" -v e="$ITEMS_END" '
    $0==s {flag=1; print; next}
    $0==e {flag=0}
    flag && /^\|/ { n++; sub(/^\| *[0-9]+ *\|/, "| " n " |") }
    { print }
  ' "$UNRELEASED_FILE" > "$tmp"
  mv "$tmp" "$UNRELEASED_FILE"
}

# Remove the rows whose item numbers are listed (space-separated) in $1,
# then renumber the remainder. Used by release-cut after a ship.
# Field-split for the item number (BSD awk has no sub() backreferences).
remove_unreleased_rows() {
  local picks=" $1 "  # padded for word-boundary match
  local tmp; tmp="$(mktemp)"
  awk -F'|' -v s="$ITEMS_START" -v e="$ITEMS_END" -v picks="$picks" '
    $0==s {flag=1; print; next}
    $0==e {flag=0; print; next}
    {
      if (flag && $0 ~ /^\|/) {
        num=$2; gsub(/[ \t]/,"",num)
        if (index(picks, " " num " ") > 0) next
      }
      print
    }
  ' "$UNRELEASED_FILE" > "$tmp"
  mv "$tmp" "$UNRELEASED_FILE"
  renumber_unreleased
  touch_unreleased_stamp
}

# Extract the app short-commit of a given item number (for cherry-pick).
unreleased_commit_for() {
  local num="$1"
  unreleased_rows | awk -F'|' -v n="$num" '
    { gsub(/^[ \t]+|[ \t]+$/, "", $2) }
    $2==n { gsub(/[` \t]/, "", $6); print $6; exit }'
}

# Extract the channel (OTA/STORE) of a given item number.
unreleased_channel_for() {
  local num="$1"
  unreleased_rows | awk -F'|' -v n="$num" '
    { gsub(/^[ \t]+|[ \t]+$/, "", $2) }
    $2==n { print ($3 ~ /Store/ ? "STORE" : "OTA"); exit }'
}
