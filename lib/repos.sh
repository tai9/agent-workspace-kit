#!/usr/bin/env bash
# The repo table: the one place that knows whether the workspace is several git
# repos or one. Everything else asks these functions and never looks at shape.
shape()      { cfg_default shape multi-repo; }
repo_names() { cfg_keys repos; }
repo_path()  { printf '%s/%s' "$WORKSPACE_ROOT" "$(cfg "repos.$1.path")"; }
repo_label() { basename "$(cfg "repos.$1.path")"; }
repo_role()  { cfg "repos.$1.role"; }
repo_guards(){ cfg_default "repos.$1.guards" true; }
repo_trunk() {
  local t; t="$(cfg "repos.$1.trunk")"
  [ -n "$t" ] || t="$(cfg_default trunk main)"
  printf '%s' "$t"
}
repo_git_dir() { if [ "$(shape)" = monorepo ]; then printf '%s' "$WORKSPACE_ROOT"; else repo_path "$1"; fi; }
repo_subdir()  { if [ "$(shape)" = monorepo ]; then cfg "repos.$1.path"; fi; }
repo_git()     { local n="$1"; shift; git -C "$(repo_git_dir "$n")" "$@"; }

# Files a commit touched, relative to the repo's own path. In a monorepo the
# commit may touch other roles' directories; those are not this repo's change.
repo_changed_files() {
  local n="$1" c="$2" sub; sub="$(repo_subdir "$n")"
  if [ -n "$sub" ]; then
    repo_git "$n" show --name-only --format= "$c" -- "$sub" 2>/dev/null | sed "s#^$sub/##" || true
  else
    repo_git "$n" show --name-only --format= "$c" 2>/dev/null || true
  fi
}

anchor_name() {
  local n; for n in $(repo_names); do
    [ "$(repo_role "$n")" = release-anchor ] && { printf '%s' "$n"; return 0; }
  done
  die "workspace.yml: no repo has role: release-anchor"
}
anchor_path()    { repo_path "$(anchor_name)"; }
anchor_git_dir() { repo_git_dir "$(anchor_name)"; }
anchor_trunk()   { repo_trunk "$(anchor_name)"; }
anchor_mirror()  { cfg "repos.$(anchor_name).mirror"; }
anchor_git()     { repo_git "$(anchor_name)" "$@"; }

service_names() { local n; for n in $(repo_names); do [ "$(repo_role "$n")" = service ] && printf '%s\n' "$n"; done; return 0; }
single_service() {
  local s; s="$(service_names)"
  [ -n "$s" ] || die "workspace.yml: no repo has role: service"
  [ "$(printf '%s\n' "$s" | wc -l | tr -d ' ')" -eq 1 ] || die "several service repos; name one with --paired <repo>:<commit>"
  printf '%s' "$s"
}
