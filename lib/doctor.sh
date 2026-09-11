#!/usr/bin/env bash
# Checks the workspace for the kinds of drift that are invisible until they
# bite: a rules file nobody reads, agent config that dies with a clone, a
# guard hook that stopped being registered, an env key documented nowhere,
# merged branches and finished worktrees piling up. Reports only; never
# changes anything.
#
# Ported from an internal workspace-doctor.sh that hardcoded its repo list;
# here the repo list comes from workspace.yml via doctor_targets(), which
# every section below iterates instead of looking at shape itself. The two
# exceptions are doctor_hooks (the relay-stub check only exists in the
# multi-repo shape) and doctor_root (a monorepo's own docs legitimately live
# at its root, so the check does not run at all).

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
fails=0; warns=0

dr_pass() { printf '  %sok%s   %s\n' "$GRN" "$OFF" "$1"; }
dr_warn() { printf '  %swarn%s %s\n' "$YEL" "$OFF" "$1"; warns=$((warns+1)); }
dr_fail() { printf '  %sFAIL%s %s\n' "$RED" "$OFF" "$1"; fails=$((fails+1)); }
dr_head() { printf '\n%s\n' "$1"; }

# One label/dir/trunk row per section iteration. In multi-repo that's one row
# per repo from workspace.yml (repo_names); in monorepo it collapses to a
# single row against WORKSPACE_ROOT, labelled with the workspace's own name.
# Every section below reads this instead of asking shape() itself, which is
# what makes "not cloned" impossible to print in a monorepo (the row's dir is
# WORKSPACE_ROOT, which always exists) and the per-repo checks run exactly
# once there.
doctor_targets() {
  if [ "$(shape)" = monorepo ]; then
    printf '%s\t%s\t%s\n' "$(cfg_default name workspace)" "$WORKSPACE_ROOT" "$(cfg_default trunk main)"
  else
    local n
    for n in $(repo_names); do
      printf '%s\t%s\t%s\n' "$(repo_label "$n")" "$(repo_path "$n")" "$(repo_trunk "$n")"
    done
  fi
}

# ── rules files ───────────────────────────────────────────────────────────────
doctor_rules() {
  dr_head "Rules files"
  local repo dir trunk c a real lines
  while IFS=$'\t' read -r repo dir trunk; do
    [ -d "$dir" ] || { dr_warn "$repo — not cloned, skipped"; continue; }
    c="$dir/CLAUDE.md"; a="$dir/AGENTS.md"
    if [ ! -e "$c" ] && [ ! -e "$a" ]; then dr_fail "$repo — no CLAUDE.md and no AGENTS.md"; continue; fi
    if [ ! -e "$a" ]; then dr_fail "$repo — AGENTS.md missing; a reader looking for it gets no rules"; continue; fi
    if [ ! -L "$c" ] && [ ! -L "$a" ]; then
      dr_fail "$repo — CLAUDE.md and AGENTS.md are both real files; they will drift apart"
    else
      real="$c"; [ -L "$c" ] && real="$a"
      lines=$(wc -l < "$real" | tr -d ' ')
      if [ "$lines" -gt 400 ]; then
        dr_warn "$repo — rules file is $lines lines; past 400 it is carrying reference material"
      else
        dr_pass "$repo — one rules file, $lines lines, the other symlinked"
      fi
    fi
  done < <(doctor_targets)
}

# ── agent config is versioned ─────────────────────────────────────────────────
doctor_agent_config() {
  dr_head "Agent config under version control"
  local repo dir trunk
  while IFS=$'\t' read -r repo dir trunk; do
    [ -d "$dir/.git" ] || continue
    if grep -qE '^\.claude/?$' "$dir/.gitignore" 2>/dev/null; then
      dr_fail "$repo — .gitignore hides all of .claude; skills and agents die with the clone"
    else
      dr_pass "$repo — .claude is not hidden wholesale"
    fi
  done < <(doctor_targets)
}

# ── hooks ─────────────────────────────────────────────────────────────────────
# The one shape-aware section. A session opened inside a product repo never
# sees the workspace's own .claude/settings.json, so in the multi-repo shape
# each product repo carries a byte copy of the canonical stub that relays to
# the workspace guards; the stub is copied, not linked (it must survive a
# standalone clone), hence the drift check. A monorepo has one settings.json
# and no relay, so that loop does not run there at all.
doctor_hooks() {
  dr_head "Hooks"
  local an agd anchor_label
  an="$(anchor_name)"; agd="$(anchor_git_dir)"
  if [ "$(shape)" = monorepo ]; then anchor_label="$(cfg_default name workspace)"
  else anchor_label="$(repo_label "$an")"; fi

  # A hook installed straight in the git dir, or through a hook manager that
  # owns a .husky directory (a monorepo consumer may already use one). A
  # manager file merely existing is not proof this kit's hook runs — it must
  # invoke the awk-post-merge file bin/install-git-hooks wrote.
  if [ -x "$agd/.git/hooks/post-merge" ] \
    || { [ -f "$agd/.husky/post-merge" ] && grep -q "awk-post-merge" "$agd/.husky/post-merge" 2>/dev/null; }; then
    dr_pass "post-merge installed in $anchor_label"
  else
    dr_warn "post-merge not installed — run bin/install-git-hooks"
  fi

  if grep -q "workspace-guards.sh" "$WORKSPACE_ROOT/.claude/settings.json" 2>/dev/null; then
    dr_pass "release guard wired in .claude/settings.json"
  else
    dr_fail "release guard not wired; a cut can run with no confirmation"
  fi

  if [ "$(shape)" != monorepo ]; then
    local stub="$KIT_ROOT/hooks/workspace-guards.stub.sh"
    local n repo dir copy wt
    for n in $(repo_names); do
      [ "$(repo_guards "$n")" = true ] || continue
      repo="$(repo_label "$n")"; dir="$(repo_path "$n")"
      copy="$dir/.claude/hooks/workspace-guards.sh"
      if [ ! -f "$copy" ]; then
        dr_fail "$repo — no .claude/hooks/workspace-guards.sh; release and PR guards are off in sessions opened there"
      elif ! cmp -s "$stub" "$copy"; then
        dr_fail "$repo — workspace-guards.sh differs from hooks/workspace-guards.stub.sh"
      elif ! grep -q "workspace-guards.sh" "$dir/.claude/settings.json" 2>/dev/null; then
        dr_fail "$repo — workspace-guards.sh present but not registered in .claude/settings.json"
      else
        dr_pass "$repo — workspace guards stub in place and registered"
      fi
      # A worktree branched before the hooks landed runs with none of them
      # until it is rebased; say so rather than let it look protected.
      # Compare against git's own resolved path for the main checkout, not
      # $dir verbatim — /tmp is a symlink to /private/tmp on macOS and git
      # reports the resolved form, which would otherwise never match.
      local dir_real; dir_real="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")"
      for wt in $(git -C "$dir" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'); do
        [ "$wt" = "$dir_real" ] && continue
        [ -f "$wt/.claude/hooks/workspace-guards.sh" ] \
          || dr_warn "$repo — worktree $(basename "$wt") predates the guard stub; rebase it onto trunk to get the hooks"
      done
    done
  fi
}

# ── CI ───────────────────────────────────────────────────────────────────────
# A repo with a test suite and no workflow is the shape every repo has until
# the suite is wired up; this is what stops it coming back.
doctor_ci() {
  dr_head "CI"
  local repo dir trunk tests wf f
  while IFS=$'\t' read -r repo dir trunk; do
    [ -d "$dir/.git" ] || continue
    # git ls-files, not find: find walks worktrees under .claude/ too and
    # double-counts the same suite once per checkout.
    tests=$(git -C "$dir" ls-files \
      | grep -cE '\.spec\.ts$|_test\.dart$|\.test\.ts$' || true)
    wf=0
    for f in "$dir"/.github/workflows/*.yml; do [ -f "$f" ] && wf=$((wf+1)); done
    if [ "$tests" -gt 0 ] && [ "$wf" -eq 0 ]; then
      dr_fail "$repo — $tests test files and no workflow running them"
    elif [ "$wf" -gt 0 ]; then
      dr_pass "$repo — $wf workflow(s)"
    else
      dr_pass "$repo — no test suite, no workflow needed"
    fi
  done < <(doctor_targets)
}

# ── .env.example completeness ─────────────────────────────────────────────────
# Each .env.<x> is checked against .env.<x>.example when that exists, and
# against the base .env.example otherwise. Comparing everything to one file
# reports keys as missing when they are in fact documented next door.
doctor_env() {
  dr_head "Env keys documented in .env.example"
  local repo dir trunk missing f ex documented k
  while IFS=$'\t' read -r repo dir trunk; do
    [ -f "$dir/.env.example" ] || continue
    missing=""
    for f in "$dir"/.env "$dir"/.env.*; do
      case "$f" in *.example) continue;; esac
      [ -f "$f" ] || continue
      ex="$f.example"; [ -f "$ex" ] || ex="$dir/.env.example"
      documented="$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$ex" | sort -u || true)"
      for k in $(grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$f" | sort -u || true); do
        printf '%s\n' "$documented" | grep -qx "$k" || missing="$missing $(basename "$ex"):$k"
      done
    done
    missing="$(printf '%s\n' $missing | sort -u | tr '\n' ' ')"
    [ -z "${missing// /}" ] && dr_pass "$repo — every key appears in its .env.example" \
      || dr_fail "$repo — undocumented:${missing% }"
  done < <(doctor_targets)
}

# ── branches and worktrees ────────────────────────────────────────────────────
doctor_branches() {
  dr_head "Branches and worktrees"
  local adir amirror
  adir="$(anchor_git_dir)"; amirror="$(anchor_mirror)"
  local repo dir trunk mirror stale b mb files differs f wt
  while IFS=$'\t' read -r repo dir trunk; do
    [ -d "$dir/.git" ] || continue
    mirror=""; [ "$dir" = "$adir" ] && mirror="$amirror"
    stale=0
    while read -r b; do
      [ -z "$b" ] && continue
      [ "$b" = "$trunk" ] && continue
      [ -n "$mirror" ] && [ "$b" = "$mirror" ] && continue
      git -C "$dir" rev-parse --verify -q "refs/heads/$b" >/dev/null || continue
      mb="$(git -C "$dir" merge-base "origin/$trunk" "$b" 2>/dev/null)" || continue
      files="$(git -C "$dir" diff --name-only "$mb" "$b" || true)"
      [ -z "$files" ] && { stale=$((stale+1)); continue; }
      differs=0
      while read -r f; do
        [ -z "$f" ] && continue
        git -C "$dir" diff --quiet "$b" "origin/$trunk" -- "$f" 2>/dev/null || differs=1
      done <<< "$files"
      [ "$differs" -eq 0 ] && stale=$((stale+1))
    done <<< "$(git -C "$dir" for-each-ref --format='%(refname:short)' refs/heads)"
    [ "$stale" -eq 0 ] && dr_pass "$repo — no local branch already contained in $trunk" \
      || dr_warn "$repo — $stale local branch(es) whose content is already in $trunk"

    wt=$(git -C "$dir" worktree list --porcelain | grep -c '^worktree ' || true)
    [ "$wt" -le 1 ] && dr_pass "$repo — no extra worktrees" \
      || dr_warn "$repo — $((wt-1)) extra worktree(s) still checked out"
  done < <(doctor_targets)
}

# ── workspace root ────────────────────────────────────────────────────────────
# Loose documents at the root are what an agent reads first and trusts most; a
# superseded spec living next to CLAUDE.md is how a stale rule gets followed.
# Skipped entirely in a monorepo: its own docs legitimately live at the root.
# The skip is the caller's decision (doctor_run), not this section's — shape
# lives only in doctor_targets and the (declared exception) hooks section.
doctor_root() {
  dr_head "Workspace root"
  local loose=0 f
  for f in "$WORKSPACE_ROOT"/*.md; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in README.md|CLAUDE.md|AGENTS.md) ;; *) loose=$((loose+1));; esac
  done
  [ "$loose" -eq 0 ] && dr_pass "no loose documents beside the rules files (docs live under docs/ and releases/)" \
    || dr_warn "$loose loose .md file(s) at the workspace root — move them under docs/"
}

# ── trunk state ───────────────────────────────────────────────────────────────
doctor_trunk_state() {
  dr_head "Trunk state"
  local repo dir trunk dirty sb
  while IFS=$'\t' read -r repo dir trunk; do
    [ -d "$dir/.git" ] || continue
    dirty=$(git -C "$dir" status --porcelain | grep -vc '^?? \.claude/worktrees' || true)
    sb=$(git -C "$dir" status -sb | head -1)
    case "$sb" in
      *ahead*|*behind*) dr_warn "$repo — ${sb#\#\# }" ;;
      *) [ "$dirty" -eq 0 ] && dr_pass "$repo — clean and level with origin" \
           || dr_warn "$repo — $dirty uncommitted change(s)" ;;
    esac
  done < <(doctor_targets)
}

# ── the unreleased inventory ──────────────────────────────────────────────────
# UNRELEASED.md is read before every ship, so its value is inversely
# proportional to its length. Left ungoverned it silently becomes the place
# every hard-won lesson gets pasted: the origin workspace's copy reached 196
# lines carrying a single queued row, so finding out what was about to ship
# meant reading 190 lines of history first. The durable lessons belong in
# RELEASE_PROCESS.md and the per-release facts in that release's own note;
# what is left here is the two tables and a few lines around them.
#
# Only the prose is measured. The tables are delimited by markers and may grow
# to any size — a hundred queued items is a big queue, not drift.
doctor_inventory() {
  dr_head "Unreleased inventory"
  local limit total inside prose m
  limit="$(cfg_default release.unreleased_prose_limit 60)"
  case "$limit" in ''|*[!0-9]*) limit=60 ;; esac
  if [ ! -f "$UNRELEASED_FILE" ]; then
    dr_warn "releases/UNRELEASED.md — not created yet (\`release add\` writes it)"
    return 0
  fi
  for m in "$ITEMS_START" "$ITEMS_END"; do
    grep -qF "$m" "$UNRELEASED_FILE" || { dr_fail "releases/UNRELEASED.md — missing the $m marker; release add/cut cannot find the table"; return 0; }
  done
  total=$(wc -l < "$UNRELEASED_FILE" | tr -d ' ')
  # Everything between a START and its END, markers included, is machine-owned.
  inside=$(awk '/<!-- [A-Z]+:START -->/ {f=1} f {n++} /<!-- [A-Z]+:END -->/ {f=0} END {print n+0}' "$UNRELEASED_FILE")
  prose=$((total - inside))
  if [ "$prose" -le "$limit" ]; then
    dr_pass "releases/UNRELEASED.md — $prose lines of prose (limit $limit)"
  elif [ "$prose" -le $((limit * 2)) ]; then
    dr_warn "releases/UNRELEASED.md — $prose lines of prose, over the $limit-line limit; move durable rules to RELEASE_PROCESS.md and per-release facts to the release note"
  else
    dr_fail "releases/UNRELEASED.md — $prose lines of prose, more than twice the $limit-line limit; it is a history file now, not a queue"
  fi
}

doctor_run() {
  # Run under +e in a subshell: these checks are meant to fail sometimes and
  # keep going, the way the original script's non -e "set -uo pipefail" did.
  (
    set +e
    fails=0; warns=0
    doctor_rules
    doctor_agent_config
    doctor_hooks
    doctor_ci
    doctor_env
    doctor_inventory
    doctor_branches
    [ "$(shape)" = monorepo ] || doctor_root
    doctor_trunk_state
    printf '\n%s%d fail, %d warn%s\n' "$DIM" "$fails" "$warns" "$OFF"
    [ "$fails" -eq 0 ]
  )
}
