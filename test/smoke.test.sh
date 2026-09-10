#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
echo "harness"
is "is compares strings" "a" "a"
git_init "$TMP/r"; c=$(commit_file "$TMP/r" f.txt "one")
is "commit_file returns a sha" "40" "${#c}"
finish
