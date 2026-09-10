#!/usr/bin/env bash
# OTA/Store classification, coupling heuristic, commit metadata.
# The rule comes from workspace.yml release.store_paths: any touched path
# matching one of them forces a store build.
_regex_from_list() { # <cfg key> -> alternation; "." escaped; a bare "assets/" anchors to a path segment
  local p out=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    p="$(printf '%s' "$p" | sed 's/\./\\./g')"
    case "$p" in assets/) p='(^|/)assets/';; esac
    out="${out:+$out|}$p"
  done < <(cfg_list "$1")
  printf '%s' "$out"
}
store_regex()    { _regex_from_list release.store_paths; }
contract_regex() { _regex_from_list release.contract_paths; }

classify_commit() {
  local files re; files="$(repo_changed_files "$1" "$2")"; re="$(store_regex)"
  [ -n "$re" ] && printf '%s\n' "$files" | grep -qiE "$re" && { printf 'STORE'; return; }
  printf 'OTA'
}
channel_emoji() { [[ "$1" == "STORE" ]] && printf '🔴 Store' || printf '🟢 OTA'; }
commit_looks_coupled() {
  local files re; files="$(repo_changed_files "$1" "$2")"; re="$(contract_regex)"
  [ -n "$re" ] && printf '%s\n' "$files" | grep -qiE "$re"
}
commit_short()   { repo_git "$1" rev-parse --short=12 "$2"; }
commit_subject() { repo_git "$1" show -s --format=%s "$2"; }
commit_type() {
  local s re; s="$(commit_subject "$1" "$2")"
  re='^([a-zA-Z]+)(\([^)]*\))?!?:'
  if [[ "$s" =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; else printf 'chore'; fi
}
commit_summary() {
  local s re; s="$(commit_subject "$1" "$2")"
  re='^[a-zA-Z]+(\([^)]*\))?!?:[[:space:]]*(.*)$'
  if [[ "$s" =~ $re ]]; then printf '%s' "${BASH_REMATCH[2]}"; else printf '%s' "$s"; fi
}
