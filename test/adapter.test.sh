#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load() { WORKSPACE_ROOT="$1"; source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/adapter.sh"; load_adapter; }

echo "flutter-shorebird"
make_multi "$TMP/m"; load "$TMP/m"
is "reads the full version" "1.9.1+76" "$(anchor_version)"
is "splits the name" "1.9.1" "$(version_name "$(anchor_version)")"
is "splits the build" "76" "$(version_build "$(anchor_version)")"
printf 'name: demo\nversion: 1.9\n' > "$TMP/m/my-app/pubspec.yaml"
(anchor_version) >/dev/null 2>&1 && t_bad "a malformed version is refused" "non-zero" "0" || t_ok "a malformed version is refused"
printf 'name: demo\nversion: 1.9.1+76\n' > "$TMP/m/my-app/pubspec.yaml"
mkdir -p "$TMP/wt"; printf 'version: 2.0.0+1\n' > "$TMP/wt/pubspec.yaml"
is "reads another checkout" "2.0.0+1" "$(anchor_version_in "$TMP/wt")"

echo "flutter-shorebird: anchor_release / anchor_patch (multi-repo, no subdir)"
mkdir -p "$TMP/rel_wt/scripts"
cat > "$TMP/rel_wt/scripts/shorebird-release.sh" <<'EOF'
#!/usr/bin/env bash
{ printf 'args=%s %s %s\n' "$1" "$2" "$3"; printf 'pwd=%s\n' "$PWD"; } > "$LOG"
EOF
chmod +x "$TMP/rel_wt/scripts/shorebird-release.sh"
LOG="$TMP/rel.log" anchor_release stg android yes "$TMP/rel_wt" >/dev/null 2>&1
is "release args in order env,platform,distribute" "args=stg android yes" "$(head -n1 "$TMP/rel.log")"
is "release runs from the worktree root (no subdir, no trailing slash)" "pwd=$TMP/rel_wt" "$(sed -n 2p "$TMP/rel.log")"

mkdir -p "$TMP/m/my-app/scripts"
cat > "$TMP/m/my-app/scripts/shorebird-patch.sh" <<'EOF'
#!/usr/bin/env bash
{ printf 'wrapper=current\n'; printf 'args=%s %s\n' "$1" "$2"; printf 'pwd=%s\n' "$PWD"; printf 'ALLOW_ASSET_DIFFS=%s\n' "${ALLOW_ASSET_DIFFS-}"; } > "$LOG"
EOF
chmod +x "$TMP/m/my-app/scripts/shorebird-patch.sh"
mkdir -p "$TMP/patch_wt/scripts"
cat > "$TMP/patch_wt/scripts/shorebird-patch.sh" <<'EOF'
#!/usr/bin/env bash
printf 'wrapper=old\n' > "$LOG"
EOF
chmod +x "$TMP/patch_wt/scripts/shorebird-patch.sh"
LOG="$TMP/patch.log" anchor_patch stg android "$TMP/patch_wt" 1 >/dev/null 2>&1
is "patch copies the CURRENT wrapper from the anchor over the worktree's" "wrapper=current" "$(head -n1 "$TMP/patch.log")"
is "patch args in order env,platform" "args=stg android" "$(sed -n 2p "$TMP/patch.log")"
is "patch runs from the worktree root" "pwd=$TMP/patch_wt" "$(sed -n 3p "$TMP/patch.log")"
is "patch exports ALLOW_ASSET_DIFFS" "ALLOW_ASSET_DIFFS=1" "$(sed -n 4p "$TMP/patch.log")"
is "the worktree's wrapper file is now the anchor's current one" "$(cat "$TMP/m/my-app/scripts/shorebird-patch.sh")" "$(cat "$TMP/patch_wt/scripts/shorebird-patch.sh")"

echo "monorepo path"
make_mono "$TMP/o"; load "$TMP/o"
is "reads app/pubspec.yaml" "1.0.0+6" "$(anchor_version)"
mkdir -p "$TMP/wt2/app"; printf 'version: 1.0.0+7\n' > "$TMP/wt2/app/pubspec.yaml"
is "reads another checkout under the subdir" "1.0.0+7" "$(anchor_version_in "$TMP/wt2")"

echo "flutter-shorebird: anchor_release / anchor_patch (monorepo, with subdir)"
mkdir -p "$TMP/rel_wt2/app/scripts"
cat > "$TMP/rel_wt2/app/scripts/shorebird-release.sh" <<'EOF'
#!/usr/bin/env bash
{ printf 'args=%s %s %s\n' "$1" "$2" "$3"; printf 'pwd=%s\n' "$PWD"; } > "$LOG"
EOF
chmod +x "$TMP/rel_wt2/app/scripts/shorebird-release.sh"
LOG="$TMP/rel2.log" anchor_release stg ios no "$TMP/rel_wt2" >/dev/null 2>&1
is "monorepo release args in order" "args=stg ios no" "$(head -n1 "$TMP/rel2.log")"
is "monorepo release runs from worktree/<subdir>" "pwd=$TMP/rel_wt2/app" "$(sed -n 2p "$TMP/rel2.log")"

mkdir -p "$TMP/o/app/scripts"
cat > "$TMP/o/app/scripts/shorebird-patch.sh" <<'EOF'
#!/usr/bin/env bash
{ printf 'wrapper=current\n'; printf 'pwd=%s\n' "$PWD"; } > "$LOG"
EOF
chmod +x "$TMP/o/app/scripts/shorebird-patch.sh"
mkdir -p "$TMP/patch_wt2/app/scripts"
cat > "$TMP/patch_wt2/app/scripts/shorebird-patch.sh" <<'EOF'
#!/usr/bin/env bash
printf 'wrapper=old\n' > "$LOG"
EOF
chmod +x "$TMP/patch_wt2/app/scripts/shorebird-patch.sh"
LOG="$TMP/patch2.log" anchor_patch stg ios "$TMP/patch_wt2" 0 >/dev/null 2>&1
is "monorepo patch copies the current wrapper" "wrapper=current" "$(head -n1 "$TMP/patch2.log")"
is "monorepo patch runs from worktree/<subdir>" "pwd=$TMP/patch_wt2/app" "$(sed -n 2p "$TMP/patch2.log")"

echo "generic-semver"
mkdir -p "$TMP/g/svc"; git_init "$TMP/g"; printf '3.2.1+9\n' > "$TMP/g/svc/VERSION"
cat > "$TMP/g/fake-cmd.sh" <<'EOF'
#!/usr/bin/env bash
{
  printf 'ENV=%s PLATFORM=%s DISTRIBUTE=%s ALLOW_ASSET_DIFFS=%s\n' "${ENV-}" "${PLATFORM-}" "${DISTRIBUTE-}" "${ALLOW_ASSET_DIFFS-}"
  printf 'pwd=%s\n' "$PWD"
} > "$LOG"
EOF
chmod +x "$TMP/g/fake-cmd.sh"
cat > "$TMP/g/workspace.yml" <<EOF
shape: monorepo
trunk: main
repos: { svc: { path: svc, role: release-anchor } }
release: { adapter: generic-semver, anchor_file: svc/VERSION, release_cmd: "$TMP/g/fake-cmd.sh", patch_cmd: "$TMP/g/fake-cmd.sh" }
EOF
load "$TMP/g"
is "reads VERSION" "3.2.1+9" "$(anchor_version)"
mkdir -p "$TMP/gwt/svc"
LOG="$TMP/g/release.log" anchor_release stg android yes "$TMP/gwt" >/dev/null 2>&1
is "release_cmd sees ENV/PLATFORM/DISTRIBUTE in order" "ENV=stg PLATFORM=android DISTRIBUTE=yes ALLOW_ASSET_DIFFS=" "$(head -n1 "$TMP/g/release.log")"
is "release_cmd runs from worktree/<subdir>" "pwd=$TMP/gwt/svc" "$(sed -n 2p "$TMP/g/release.log")"
LOG="$TMP/g/patch.log" anchor_patch stg android "$TMP/gwt" 1 >/dev/null 2>&1
is "patch_cmd sees ENV/PLATFORM/ALLOW_ASSET_DIFFS" "ENV=stg PLATFORM=android DISTRIBUTE= ALLOW_ASSET_DIFFS=1" "$(head -n1 "$TMP/g/patch.log")"
is "patch_cmd runs from worktree/<subdir>" "pwd=$TMP/gwt/svc" "$(sed -n 2p "$TMP/g/patch.log")"

printf 'not-a-version\n' > "$TMP/g/svc/VERSION"
(anchor_version) >/dev/null 2>&1 && t_bad "a malformed VERSION is refused" "non-zero" "0" || t_ok "a malformed VERSION is refused"

printf ' 3.2.1+9 \n\n' > "$TMP/g/svc/VERSION"
is "tolerates surrounding whitespace and a trailing newline" "3.2.1+9" "$(anchor_version)"

echo "generic-semver: dies without release_cmd/patch_cmd"
mkdir -p "$TMP/g2/svc"; git_init "$TMP/g2"; printf '1.0.0+1\n' > "$TMP/g2/svc/VERSION"
cat > "$TMP/g2/workspace.yml" <<'EOF'
shape: monorepo
trunk: main
repos: { svc: { path: svc, role: release-anchor } }
release: { adapter: generic-semver, anchor_file: svc/VERSION }
EOF
load "$TMP/g2"
mkdir -p "$TMP/g2wt/svc"
(anchor_release stg android yes "$TMP/g2wt") >/dev/null 2>&1 && t_bad "anchor_release dies without release_cmd" "non-zero" "0" || t_ok "anchor_release dies without release_cmd"
(anchor_patch stg android "$TMP/g2wt" 0) >/dev/null 2>&1 && t_bad "anchor_patch dies without patch_cmd" "non-zero" "0" || t_ok "anchor_patch dies without patch_cmd"

echo "unknown adapter"
sed -i.bak 's/generic-semver/nope/' "$TMP/g/workspace.yml"
( load "$TMP/g" ) >/dev/null 2>&1 && t_bad "unknown adapter dies" "non-zero" "0" || t_ok "unknown adapter dies"

echo "adapter missing a required function"
tmp_kit="$TMP/fakekit"; mkdir -p "$tmp_kit/adapters"
cat > "$tmp_kit/adapters/incomplete.sh" <<'EOF'
#!/usr/bin/env bash
# Deliberately missing anchor_release and anchor_patch.
read_version_file() { :; }
anchor_version() { :; }
EOF
mkdir -p "$TMP/inc"; git_init "$TMP/inc"
cat > "$TMP/inc/workspace.yml" <<'EOF'
shape: monorepo
trunk: main
repos: { app: { path: ., role: release-anchor } }
release: { adapter: incomplete, anchor_file: VERSION }
EOF
# A fresh process: anchor_release/anchor_patch etc. from adapters loaded
# earlier in this script are already-defined bash functions, and a subshell
# would inherit them, masking a genuinely incomplete adapter. A new bash
# process starts with none of that baggage.
env -i PATH="$PATH" TMP="$TMP" KIT="$KIT" tmp_kit="$tmp_kit" bash -c '
  WORKSPACE_ROOT="$TMP/inc"
  source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"
  KIT_ROOT="$tmp_kit"
  source "$KIT/lib/adapter.sh"
  load_adapter
' >/dev/null 2>&1 && t_bad "adapter missing a required function dies" "non-zero" "0" || t_ok "adapter missing a required function dies"

finish
