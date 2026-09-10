#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mkdir -p "$TMP/ws/sub/deeper"
cat > "$TMP/ws/workspace.yml" <<'EOF'
name: Demo
shape: monorepo
repos:
  app: { path: app, role: release-anchor }
  backend: { path: backend, role: service }
release:
  store_paths: [android/, .gradle]
preflight:
  endpoints:
    - /health
    - path: /v
      expect: ok
a.b: 1
a-b: 2
EOF
echo "config"
cd "$TMP/ws/sub/deeper"
source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"
is "finds the root above cwd" "$TMP/ws" "$WORKSPACE_ROOT"
is "reads a scalar" "monorepo" "$(cfg shape)"
is "reads a nested scalar" "release-anchor" "$(cfg repos.app.role)"
is "missing key is empty" "" "$(cfg nope.nothing)"
is "default applies" "main" "$(cfg_default trunk main)"
is "lists items" "android/ .gradle" "$(cfg_list release.store_paths | tr '\n' ' ' | sed 's/ $//')"
is "map keys" "app backend" "$(cfg_keys repos | tr '\n' ' ' | sed 's/ $//')"
is "string list item as path" "/health" "$(cfg preflight.endpoints.0)"
is "object list item" "ok" "$(cfg preflight.endpoints.1.expect)"

# missing key never kills a caller under set -e
( set -e; cfg nope.nothing >/dev/null; echo survived ) >/tmp/_cfg_out.$$ 2>&1
is "missing key does not exit non-zero under set -e" "survived" "$(cat /tmp/_cfg_out.$$)"
rm -f "/tmp/_cfg_out.$$"

# cfg_list on a missing key prints nothing and exits 0
out="$(cfg_list nope.nothing)"; rc=$?
is "cfg_list on missing key prints nothing" "" "$out"
is "cfg_list on missing key exits 0" "0" "$rc"

# cfg_keys dedupes: "repos.app" is itself a map with two leaf keys (path, role),
# which would print "app" twice without the dedupe (and "backend" twice too).
raw_count="$(printf '%s\n' "$CFG_FLAT" | grep -c '^repos\.app\.')"
is "repos.app has more than one leaf key (fixture actually exercises dedupe)" "true" "$([ "$raw_count" -gt 1 ] && echo true || echo false)"
is "cfg_keys still returns app exactly once" "1" "$(cfg_keys repos | grep -c '^app$')"
is "cfg_keys still returns backend exactly once" "1" "$(cfg_keys repos | grep -c '^backend$')"

# _cfg_escape: a "." in a dotted key pattern must not act as a wildcard, so a
# key differing only by "." vs another character must not cross-match.
is "a.b lookup returns its own value" "1" "$(cfg a.b)"
is "a-b lookup returns its own value, not a.b's" "2" "$(cfg a-b)"

mkdir -p "$TMP/ws/.claude/worktrees/t/x"; cp "$TMP/ws/workspace.yml" "$TMP/ws/.claude/worktrees/t/"
cd "$TMP/ws/.claude/worktrees/t/x"
unset WORKSPACE_ROOT; source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"
is "a workspace worktree resolves to the real root" "$TMP/ws" "$WORKSPACE_ROOT"
cd "$TMP"; unset WORKSPACE_ROOT
( source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh" ) >/dev/null 2>&1 && t_bad "no workspace.yml dies" "exit 1" "exit 0" || t_ok "no workspace.yml dies"

# malformed workspace.yml makes sourcing lib/config.sh fail rather than silently continue
mkdir -p "$TMP/bad"
printf 'a: [unclosed\n' > "$TMP/bad/workspace.yml"
( cd "$TMP/bad" && unset WORKSPACE_ROOT && source "$KIT/lib/out.sh" && source "$KIT/lib/config.sh" ) >/dev/null 2>&1 \
  && t_bad "malformed workspace.yml dies" "exit 1" "exit 0" || t_ok "malformed workspace.yml dies"

finish
