#!/usr/bin/env bash
# Shared harness for test/*.test.sh. Source it first, then write tests.
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
t_ok()  { printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
t_bad() { printf '  \033[31mFAIL\033[0m %s\n           expected: %s\n                got: %s\n' "$1" "$2" "$3"; fail=$((fail+1)); }
is()    { [ "$2" = "$3" ] && t_ok "$1" || t_bad "$1" "$2" "$3"; }
finish() { printf '%d passed, %d failed\n' "$pass" "$fail"; [ "$fail" -eq 0 ]; }

# A git repo with one commit, identity set. Prints nothing; use the path you passed.
# The root commit's author/committer dates are pinned so two independent
# git_init calls (e.g. a fixture repo and a throwaway local "origin" for it)
# produce a byte-identical, same-SHA root commit — letting the fixture push
# its real history onto the "origin" as a clean fast-forward instead of
# racing real wall-clock seconds for a coincidental hash collision.
git_init() { # <dir>
  mkdir -p "$1"; git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.com; git -C "$1" config user.name Test
  GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" \
    git -C "$1" commit -q --allow-empty -m "root"
}
# Append to a file and commit it. Prints the commit sha.
commit_file() { # <repo> <path> <message>
  mkdir -p "$1/$(dirname "$2")"; echo x >> "$1/$2"
  git -C "$1" add -A; git -C "$1" commit -qm "$3"; git -C "$1" rev-parse HEAD
}
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

# Multi-repo workspace: <dir>/workspace.yml, <dir>/my-app (git, pubspec), <dir>/my-be (git).
make_multi() {
  mkdir -p "$1"; git_init "$1/my-app"; git_init "$1/my-be"
  printf 'name: demo\nversion: 1.9.1+76\n' > "$1/my-app/pubspec.yaml"
  git -C "$1/my-app" add -A; git -C "$1/my-app" commit -qm "pubspec"
  git -C "$1/my-app" branch develop
  cat > "$1/workspace.yml" <<'EOF'
name: Demo
shape: multi-repo
repos:
  app: { path: my-app, trunk: develop, role: release-anchor, mirror: main }
  backend: { path: my-be, trunk: main, role: service }
release:
  adapter: flutter-shorebird
  anchor_file: my-app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/core/services/api_service]
EOF
}
# Monorepo workspace: <dir> is one git repo with app/ and backend/.
make_mono() {
  git_init "$1"; mkdir -p "$1/app" "$1/backend"
  printf 'name: demo\nversion: 1.0.0+6\n' > "$1/app/pubspec.yaml"
  cat > "$1/workspace.yml" <<'EOF'
name: Demo
shape: monorepo
trunk: main
repos:
  app: { path: app, role: release-anchor, mirror: release }
  backend: { path: backend, role: service }
release:
  adapter: flutter-shorebird
  anchor_file: app/pubspec.yaml
  tag: "released/{version}"
  store_paths: [android/, ios/, pubspec, .gradle, Podfile, Info.plist, AndroidManifest, assets/]
  contract_paths: [lib/services/scorer]
EOF
  git -C "$1" add -A; git -C "$1" commit -qm "workspace"
}
