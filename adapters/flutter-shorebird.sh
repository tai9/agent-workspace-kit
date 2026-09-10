#!/usr/bin/env bash
# Version anchor: pubspec.yaml. Ship: the anchor repo's own Shorebird wrappers
# (release.release_cmd / release.patch_cmd, relative to the anchor path).
read_version_file() {
  local f="$1" line ver
  [[ -f "$f" ]] || die "pubspec.yaml not found at $f"
  line="$(grep -E '^version:[[:space:]]' "$f" | head -n1)"
  ver="$(printf '%s' "$line" | sed -E 's/^version:[[:space:]]*//')"
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] \
    || die "Unexpected pubspec version '$ver' (expected e.g. 1.0.1+36)"
  printf '%s' "$ver"
}
anchor_version() { read_version_file "$(anchor_version_file)"; }
# anchor_release <env> <platform> <distribute> <worktree>
anchor_release() {
  local cmd; cmd="$(cfg_default release.release_cmd scripts/shorebird-release.sh)"
  local dir
  dir="$4/$(repo_subdir "$(anchor_name)")"; dir="${dir%/}"
  ( cd "$dir" && "$cmd" "$1" "$2" "$3" )
}
# anchor_patch <env> <platform> <worktree> <allow_asset_diffs>
anchor_patch() {
  local cmd; cmd="$(cfg_default release.patch_cmd scripts/shorebird-patch.sh)"
  local dir
  dir="$3/$(repo_subdir "$(anchor_name)")"; dir="${dir%/}"
  # Ship with the *current* wrapper, not the tag's snapshot, so wrapper fixes
  # apply even when patching a base whose committed scripts/ predates them.
  cp "$(anchor_path)/$cmd" "$dir/$cmd" \
    || die "cannot ship a patch: the current wrapper is missing at $(anchor_path)/$cmd"
  ( cd "$dir" && ALLOW_ASSET_DIFFS="$4" "$cmd" "$1" "$2" )
}
