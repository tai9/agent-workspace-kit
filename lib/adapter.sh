#!/usr/bin/env bash
# Loads the version adapter named in workspace.yml and checks its contract.
anchor_version_file() { printf '%s/%s' "$WORKSPACE_ROOT" "$(cfg release.anchor_file)"; }
version_name()  { printf '%s' "$1" | sed -E 's/\+[0-9]+$//'; }
version_build() { printf '%s' "$1" | sed -E 's/^.*\+//'; }
# The anchor file inside another checkout of the anchor repo (a release worktree).
anchor_version_in() {
  local f; f="$(cfg release.anchor_file)"
  [ "$(shape)" = monorepo ] || f="${f#$(cfg "repos.$(anchor_name).path")/}"
  read_version_file "$1/$f"
}
# Basenames of the adapters actually on disk (never a hardcoded list), so
# error messages can say what's available without lib/ naming any of them.
_available_adapters() {
  local f names=()
  for f in "$KIT_ROOT"/adapters/*.sh; do
    [ -f "$f" ] || continue
    names+=("$(basename "$f" .sh)")
  done
  (IFS=,; printf '%s' "${names[*]-}")
}
load_adapter() {
  local name file fn avail; name="$(cfg release.adapter)"
  avail="$(_available_adapters)"; avail="${avail:-none found in $KIT_ROOT/adapters}"
  [ -n "$name" ] || die "workspace.yml: release.adapter is required (available: $avail)"
  file="$KIT_ROOT/adapters/$name.sh"
  [ -f "$file" ] || die "unknown release adapter '$name' (available: $avail)"
  # shellcheck disable=SC1090
  source "$file"
  for fn in read_version_file anchor_version anchor_release anchor_patch; do
    declare -F "$fn" >/dev/null || die "adapter $name does not define $fn"
  done
}
