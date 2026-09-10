#!/usr/bin/env bash
# Version anchor: a VERSION file holding name+build. Ship: project commands from
# release.release_cmd / release.patch_cmd, run inside the checkout with
# VERSION, ENV, PLATFORM exported. release_cmd must bump VERSION itself.
read_version_file() {
  local f="$1" ver
  [[ -f "$f" ]] || die "VERSION file not found at $f"
  ver="$(head -n1 "$f" | tr -d '[:space:]')"
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] || die "Unexpected version '$ver' in $f (expected e.g. 1.0.1+36)"
  printf '%s' "$ver"
}
anchor_version() { read_version_file "$(anchor_version_file)"; }
anchor_release() {
  local cmd; cmd="$(cfg release.release_cmd)"; [ -n "$cmd" ] || die "release.release_cmd is required by generic-semver"
  local dir
  dir="$4/$(repo_subdir "$(anchor_name)")"; dir="${dir%/}"
  ( cd "$dir" && ENV="$1" PLATFORM="$2" DISTRIBUTE="$3" bash -c "$cmd" )
}
anchor_patch() {
  local cmd; cmd="$(cfg release.patch_cmd)"; [ -n "$cmd" ] || die "release.patch_cmd is required by generic-semver"
  local dir
  dir="$3/$(repo_subdir "$(anchor_name)")"; dir="${dir%/}"
  ( cd "$dir" && ENV="$1" PLATFORM="$2" ALLOW_ASSET_DIFFS="$4" bash -c "$cmd" )
}
