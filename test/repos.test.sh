#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load() { WORKSPACE_ROOT="$1"; source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; }

echo "multi-repo"
make_multi "$TMP/m"; load "$TMP/m"
is "shape" "multi-repo" "$(shape)"
is "anchor by role" "app" "$(anchor_name)"
is "anchor path" "$TMP/m/my-app" "$(anchor_path)"
is "git dir is the repo" "$TMP/m/my-app" "$(repo_git_dir app)"
is "label is the basename" "my-app" "$(repo_label app)"
is "trunk per repo" "develop" "$(repo_trunk app)"
is "no subdir" "" "$(repo_subdir app)"
is "mirror" "main" "$(anchor_mirror)"
is "one service" "backend" "$(single_service)"
is "guards default on" "true" "$(repo_guards app)"
c=$(commit_file "$TMP/m/my-app" lib/a.dart "x")
is "changed files" "lib/a.dart" "$(repo_changed_files app "$c")"
is "repo_names order" "app
backend" "$(repo_names)"

echo "monorepo"
make_mono "$TMP/o"; load "$TMP/o"
is "git dir is the root" "$TMP/o" "$(repo_git_dir app)"
is "path is the subdir" "$TMP/o/app" "$(repo_path app)"
is "subdir" "app" "$(repo_subdir app)"
is "trunk is the top-level one" "main" "$(repo_trunk backend)"
c=$(commit_file "$TMP/o" app/lib/a.dart "x"); c2=$(commit_file "$TMP/o" backend/src/b.ts "y")
is "changed files are scoped and stripped" "lib/a.dart" "$(repo_changed_files app "$c")"

echo "extra: monorepo change scoping"
# c2 touched only backend/ - app must see nothing from it
is "unrelated commit yields nothing" "" "$(repo_changed_files app "$c2")"

# a commit touching both roles at once
mkdir -p "$TMP/o/app/lib" "$TMP/o/backend/src"
echo y >> "$TMP/o/app/lib/c.dart"; echo y >> "$TMP/o/backend/src/c.ts"
git -C "$TMP/o" add -A; git -C "$TMP/o" commit -qm "both roles"
cboth="$(git -C "$TMP/o" rev-parse HEAD)"
is "both-roles commit: app side only, stripped" "lib/c.dart" "$(repo_changed_files app "$cboth")"
is "both-roles commit: backend side only, stripped" "src/c.ts" "$(repo_changed_files backend "$cboth")"

echo "extra: nonexistent commit"
out="$(repo_changed_files app deadbeefdeadbeefdeadbeefdeadbeefdeadbeef)"; rc=$?
is "nonexistent commit-ish returns empty" "" "$out"
is "nonexistent commit-ish exits 0" "0" "$rc"

echo "extra: anchor_name dies without a release-anchor"
mkdir -p "$TMP/noanchor"
git_init "$TMP/noanchor/my-be"
cat > "$TMP/noanchor/workspace.yml" <<'EOF'
name: NoAnchor
shape: multi-repo
repos:
  backend: { path: my-be, role: service }
EOF
( load "$TMP/noanchor"; anchor_name >/dev/null 2>&1 )
is "anchor_name dies (no release-anchor)" "1" "$?"

echo "extra: single_service dies with two services"
mkdir -p "$TMP/twosvc"
git_init "$TMP/twosvc/my-app"; git_init "$TMP/twosvc/svc-a"; git_init "$TMP/twosvc/svc-b"
cat > "$TMP/twosvc/workspace.yml" <<'EOF'
name: TwoServices
shape: multi-repo
repos:
  app: { path: my-app, role: release-anchor }
  svc-a: { path: svc-a, role: service }
  svc-b: { path: svc-b, role: service }
EOF
( load "$TMP/twosvc"; single_service >/dev/null 2>&1 )
is "single_service dies (two services)" "1" "$?"

echo "extra: repo_guards explicit false"
mkdir -p "$TMP/guardoff"
git_init "$TMP/guardoff/my-app"
cat > "$TMP/guardoff/workspace.yml" <<'EOF'
name: GuardOff
shape: multi-repo
repos:
  app: { path: my-app, role: release-anchor, guards: false }
EOF
load "$TMP/guardoff"
is "guards explicit false" "false" "$(repo_guards app)"

finish
