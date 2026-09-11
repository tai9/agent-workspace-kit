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
# Seeded from the kit's own templates/releases/UNRELEASED.md, the single place
# the file's shape is defined: `init` writes that template for a new workspace
# and this writes the same bytes for a workspace that never ran `init`. The two
# used to carry separate copies, which is exactly how a heading drifts from the
# thing that parses it.
#
# Tokens are substituted by literal concatenation in awk, not gsub: a `&` in
# the replacement is the matched text to gsub, so a workspace named "Pen & Pad"
# would corrupt its own heading. The values arrive through the environment
# rather than -v, which pre-decodes backslash escapes in what it is given.
subst_tokens() {
  AWK_NAME="$1" AWK_TRUNK="$2" awk '
    BEGIN { name = ENVIRON["AWK_NAME"]; trunk = ENVIRON["AWK_TRUNK"] }
    function lit(line, tok, val,   out, rest, i, n) {
      n = length(tok); out = ""; rest = line
      while ((i = index(rest, tok)) > 0) {
        out = out substr(rest, 1, i - 1) val
        rest = substr(rest, i + n)
      }
      return out rest
    }
    { line = lit($0, "{{NAME}}", name); print lit(line, "{{TRUNK}}", trunk) }
  '
}

ensure_unreleased() {
  [[ -f "$UNRELEASED_FILE" ]] && return 0
  mkdir -p "$RELEASES_DIR"
  local tpl="$KIT_ROOT/templates/releases/UNRELEASED.md"
  [[ -f "$tpl" ]] || die "missing inventory template: $tpl"
  subst_tokens "$(cfg_default name Workspace)" "$(anchor_trunk)" < "$tpl" > "$UNRELEASED_FILE"
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
