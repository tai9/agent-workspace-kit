#!/usr/bin/env bash
#
# Parity harness: runs VieSpeak's original scripts/ and this kit against the
# SAME real workspace, on the same inputs, and diffs their outputs. This is
# the gate that decides whether the extraction (Tasks 1-16) is a refactor or
# a rewrite wearing a refactor's clothes.
#
# Usage: test/parity.sh <path-to-viespeak-workspace>
#
# Safety: this script never writes into <workspace>. It copies scripts/ and
# releases/ into two throwaway roots under $TMPDIR and symlinks the product
# repos in read-only (only `git` read commands are ever run against them
# directly — log, show, rev-parse, tag --list, status; never a write). Each
# tool set gets its own scratch root so neither can touch the real releases/.
#
# Prints "parity: N/7 identical" and exits non-zero unless all seven match.

set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

WS="${1:-}"
[ -n "$WS" ] && [ -d "$WS" ] || { echo "usage: test/parity.sh <path-to-viespeak-workspace>" >&2; exit 2; }
WS="$(cd "$WS" && pwd)"
[ -d "$WS/scripts" ] && [ -d "$WS/releases" ] || { echo "$WS does not look like the VieSpeak workspace (no scripts/ or releases/)" >&2; exit 2; }

REPOS="viespeak-app viespeak-be viespeak-landing viespeak-ai-content-sdk viespeak-marketing"

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/awk-parity.XXXXXX")"
ROOT="$(cd "$ROOT" && pwd)"  # normalise (TMPDIR can carry a trailing slash, e.g. macOS's /tmp)
trap 'rm -rf "$ROOT"' EXIT
OLD="$ROOT/old"
NEW="$ROOT/new"
mkdir -p "$OLD" "$NEW"

# --- old/: VieSpeak's own tooling, run unmodified -----------------------
cp -R "$WS/scripts" "$OLD/scripts"
cp -R "$WS/releases" "$OLD/releases"
mkdir -p "$OLD/.claude"
[ -f "$WS/.claude/settings.json" ] && cp "$WS/.claude/settings.json" "$OLD/.claude/settings.json"
for r in $REPOS; do ln -s "$WS/$r" "$OLD/$r"; done

# --- new/: the kit, driven by a workspace.yml describing the same shape --
cp -R "$WS/releases" "$NEW/releases"
for r in $REPOS; do ln -s "$WS/$r" "$NEW/$r"; done
mkdir -p "$NEW/node_modules"
ln -s "$KIT" "$NEW/node_modules/agent-workspace-kit"
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/parity-workspace.yml" "$NEW/workspace.yml"

# --- guard 1: verify by construction, not by assumption, that each side's
# copied tooling actually resolves its own notion of "the workspace root" to
# our scratch root and not to $WS. Both root-resolution mechanisms compute a
# path from the sourced file's own location — a die() before ever reaching
# a command that writes, if either resolves outside $ROOT.
old_resolved="$(cd "$OLD" && bash -c 'source scripts/lib/release-common.sh >/dev/null 2>&1; printf "%s" "$WORKSPACE_ROOT"')"
new_resolved="$(cd "$NEW" && WORKSPACE_ROOT="$NEW" bash -c 'source "'"$KIT"'/lib/release-common.sh" >/dev/null 2>&1; printf "%s" "$WORKSPACE_ROOT"')"
assert_under_root() { # <label> <resolved> <must-be-under>
  case "$2" in
    "$3"|"$3"/*) printf 'root check: %s resolved workspace root to %s (OK, under %s)\n' "$1" "$2" "$3" ;;
    *) printf 'FATAL: %s resolved workspace root to "%s", which is NOT under the scratch root "%s". Refusing to run anything that could write. Aborting before any case runs.\n' "$1" "$2" "$3" >&2; exit 3 ;;
  esac
}
assert_under_root "old (scripts/release-*.sh)" "$old_resolved" "$ROOT"
assert_under_root "new (bin/*, this kit)" "$new_resolved" "$ROOT"

# --- guard 2: the real workspace must come out of this run byte-identical
# to how it went in. Snapshot before any case runs; re-check after every
# case has finished, and fail loudly — naming exactly what changed — rather
# than let a silent mutation of the thing being measured pass as green. This
# harness never repairs $WS itself; on a mismatch it reports and stops.
guard_snapshot() {
  {
    printf 'workspace:\n'; git -C "$WS" status --porcelain=v1 -uall 2>&1
    for r in $REPOS; do
      printf 'repo:%s\n' "$r"
      git -C "$WS/$r" status --porcelain=v1 -uall 2>&1
      git -C "$WS/$r" rev-parse HEAD 2>&1
      git -C "$WS/$r" tag --list 2>&1
      git -C "$WS/$r" worktree list --porcelain 2>&1
    done
    printf 'unreleased-sha256:\n'; shasum -a 256 "$WS/releases/UNRELEASED.md" 2>&1
  }
}
GUARD_PRE="$(guard_snapshot)"
guard_check() { # call after all cases; fails loudly and aborts (exit 4) on any diff
  local post; post="$(guard_snapshot)"
  if [ "$GUARD_PRE" != "$post" ]; then
    echo "FATAL: the real workspace at $WS changed during this run. This harness must never write to it." >&2
    echo "--- before / after ---" >&2
    diff <(printf '%s\n' "$GUARD_PRE") <(printf '%s\n' "$post") >&2
    exit 4
  fi
  echo "guard: real workspace at $WS is unchanged (git status, HEAD, tags, worktrees, and releases/UNRELEASED.md checksum all match pre-run)"
}

pass=0
declare -a RESULTS=()
record() { # <label> <0-or-1-ok>
  if [ "$2" = 0 ]; then RESULTS+=("ok   $1"); pass=$((pass+1)); else RESULTS+=("FAIL $1"); fi
}

# The trunk HEAD commit is very likely already recorded in the real
# UNRELEASED.md (it's the tip of ongoing work). For case 1 to actually
# exercise a *record*, not just idempotency, strip its row (always the last
# one, since it's the most recently merged commit) from both copies before
# running `add`. This changes nothing under WS itself — only the two scratch
# copies of releases/UNRELEASED.md.
strip_last_row() {
  awk '
    /<!-- ITEMS:START -->/ {print; instart=1; next}
    /<!-- ITEMS:END -->/ {
      for (i=1;i<n;i++) print rows[i]
      instart=0; print; next
    }
    instart==1 { n++; rows[n]=$0; next }
    { print }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}
strip_last_row "$OLD/releases/UNRELEASED.md"
strip_last_row "$NEW/releases/UNRELEASED.md"

# ============================================================ case 1: add
old_add_out="$(cd "$OLD" && bash scripts/release-add.sh 2>&1 | strip_ansi)"
new_add_out="$(cd "$NEW" && WORKSPACE_ROOT="$NEW" bash "$KIT/bin/release-add" 2>&1 | strip_ansi)"
ok=0
diff <(printf '%s\n' "$old_add_out") <(printf '%s\n' "$new_add_out") >/tmp/parity-case1.diff 2>&1 || ok=1
diff <(sed -E 's/^_Last updated: .*_$/_Last updated: NORMALIZED_/' "$OLD/releases/UNRELEASED.md") \
     <(sed -E 's/^_Last updated: .*_$/_Last updated: NORMALIZED_/' "$NEW/releases/UNRELEASED.md") \
     >>/tmp/parity-case1.diff 2>&1 || ok=1
record "1. add <trunk HEAD> — row matches" "$ok"

# ============================================================ case 2: add again (idempotency)
old2="$(cd "$OLD" && bash scripts/release-add.sh 2>&1 | strip_ansi)"
new2="$(cd "$NEW" && WORKSPACE_ROOT="$NEW" bash "$KIT/bin/release-add" 2>&1 | strip_ansi)"
ok=0
diff <(printf '%s\n' "$old2") <(printf '%s\n' "$new2") >/tmp/parity-case2.diff 2>&1 || ok=1
record "2. add (same commit again) — idempotency message matches" "$ok"

# ============================================================ case 3: status
# old: the raw sed extraction, which (unlike release-status) includes the
# ITEMS:START/ITEMS:END marker comments themselves; those two lines are
# stripped before comparing, since release-status deliberately emits only
# the data rows.
old_status="$(sed -n '/ITEMS:START/,/ITEMS:END/p' "$OLD/releases/UNRELEASED.md" | grep -v -e 'ITEMS:START' -e 'ITEMS:END')"
new_status="$(cd "$NEW" && WORKSPACE_ROOT="$NEW" bash "$KIT/bin/release-status" 2>&1 | strip_ansi)"
ok=0
diff <(printf '%s\n' "$old_status") <(printf '%s\n' "$new_status") >/tmp/parity-case3.diff 2>&1 || ok=1
record "3. status — unreleased listing matches" "$ok"

# ============================================================ case 4: patch cut --dry-run
old4="$(cd "$OLD" && bash scripts/release-cut.sh patch production ios --items "1" --dry-run 2>&1 | strip_ansi)"
new4="$(cd "$NEW" && WORKSPACE_ROOT="$NEW" bash "$KIT/bin/release-cut" patch production ios --items "1" --dry-run 2>&1 | strip_ansi)"
ok=0
diff <(printf '%s\n' "$old4") <(printf '%s\n' "$new4") >/tmp/parity-case4.diff 2>&1 || ok=1
record "4. release-cut patch --dry-run — plan matches" "$ok"

# ============================================================ case 5: release cut --dry-run
old5="$(cd "$OLD" && bash scripts/release-cut.sh release production both --dry-run 2>&1 | strip_ansi)"
new5="$(cd "$NEW" && WORKSPACE_ROOT="$NEW" bash "$KIT/bin/release-cut" release production both --dry-run 2>&1 | strip_ansi)"
# Authorised difference: the version line names who bumps the build. VieSpeak's
# script calls Shorebird directly and says so; the kit ships through a
# configured adapter (release.adapter) and deliberately never names one
# ecosystem tool in core output (docs/design.md's Adapter contract is the
# whole point of Task 4-10's extraction). Normalise just that parenthetical
# before diffing; everything else on the line, and every other line, must
# still match byte for byte.
norm5() { sed -E 's/\(predicted; (shorebird|the adapter) bumps\)/(predicted; ADAPTER bumps)/'; }
ok=0
diff <(printf '%s\n' "$old5" | norm5) <(printf '%s\n' "$new5" | norm5) >/tmp/parity-case5.diff 2>&1 || ok=1
record "5. release-cut release --dry-run — plan matches (adapter-name wording excepted)" "$ok"

# ============================================================ case 6: doctor
old6="$(WORKSPACE_ROOT="$OLD" bash "$OLD/scripts/workspace-doctor.sh" 2>&1 | strip_ansi)"
new6="$(WORKSPACE_ROOT="$NEW" bash "$KIT/bin/doctor" 2>&1 | strip_ansi)"
# Drop the Hooks section itself, plus normalise the final tally line's fail
# count: it is a straight sum over every section including the one just
# excluded, so a FAIL confined to Hooks moves this number without being a
# difference in anything this task can (or should) change. The warn count on
# that same line is left untouched and still has to match.
strip_hooks() {
  awk '/^Hooks$/{skip=1;next} /^[A-Z]/{skip=0} !skip' \
  | sed -E 's/^[0-9]+ fail, ([0-9]+) warn$/N fail, \1 warn/'
}
ok=0
diff <(printf '%s\n' "$old6" | strip_hooks) <(printf '%s\n' "$new6" | strip_hooks) >/tmp/parity-case6.diff 2>&1 || ok=1
record "6. doctor — drift report matches (Hooks section excepted)" "$ok"

# ============================================================ case 7: preflight
old7="$(cd "$OLD" && bash scripts/release-preflight.sh production --mode patch 2>&1 | strip_ansi)"
new7="$(cd "$NEW" && WORKSPACE_ROOT="$NEW" bash "$KIT/bin/release-preflight" production --mode patch 2>&1 | strip_ansi)"
# Compare only the check-verdict characters, in order — the wording
# deliberately differs (e.g. "pubspec" vs "anchor version", "flutter analyze
# (viespeak-app)" vs a preflight.extra label). Case 6 above already verifies
# the doctor step byte-for-byte outside its Hooks section; the *last* verdict
# line here is workspace-doctor's own overall pass/fail, and since VieSpeak's
# product repos are not yet running this kit's hook stubs (migration is
# separate, later work — see docs/design.md "Migration"), that stub-drift
# check fails under the kit's doctor even though every non-Hooks doctor
# finding matches (case 6). So: drop the last verdict line (doctor's own)
# from this comparison too, narrowly, for the same reason case 6 excludes
# the Hooks section — it is not a difference this task can or should close.
old7_verdicts="$(printf '%s\n' "$old7" | grep -oE '^[[:space:]]*[✓✗]' | sed 's/[[:space:]]//g')"
new7_verdicts="$(printf '%s\n' "$new7" | grep -oE '^[[:space:]]*[✓✗]' | sed 's/[[:space:]]//g')"
old7_verdicts_nodoc="$(printf '%s\n' "$old7_verdicts" | sed '$d')"
new7_verdicts_nodoc="$(printf '%s\n' "$new7_verdicts" | sed '$d')"
ok=0
diff <(printf '%s\n' "$old7_verdicts_nodoc") <(printf '%s\n' "$new7_verdicts_nodoc") >/tmp/parity-case7.diff 2>&1 || ok=1
record "7. preflight — every check but workspace-doctor's own line reaches the same verdict" "$ok"

# Guard 2's check runs first, unconditionally, and prints before the parity
# score — a reader who stops reading at the score line must not be able to
# miss a mutation of the real workspace. Its failure overrides a clean 7/7:
# a parity score earned by mutating the thing being measured is not a pass.
echo
guard_check
echo
for r in "${RESULTS[@]}"; do printf '%s\n' "$r"; done
echo
echo "parity: $pass/7 identical"
[ "$pass" -eq 7 ]
