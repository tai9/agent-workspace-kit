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
git_init() { # <dir>
  mkdir -p "$1"; git -C "$1" init -q -b main
  git -C "$1" config user.email t@example.com; git -C "$1" config user.name Test
  git -C "$1" commit -q --allow-empty -m "root"
}
# Append to a file and commit it. Prints the commit sha.
commit_file() { # <repo> <path> <message>
  mkdir -p "$1/$(dirname "$2")"; echo x >> "$1/$2"
  git -C "$1" add -A; git -C "$1" commit -qm "$3"; git -C "$1" rev-parse HEAD
}
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
