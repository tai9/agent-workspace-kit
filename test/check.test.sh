#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# bin/check's ecosystem grep and its doctor step both walk from a scratch
# copy of the kit's own tree, with test/run.sh stubbed to a no-op so this
# doesn't recursively re-run the whole suite (or shellcheck, which is slow
# and already covered elsewhere).
mk_kit_copy() {
  local dest="$1" _d
  mkdir -p "$dest"
  for _d in bin lib hooks git-hooks adapters templates; do
    cp -R "$KIT/$_d" "$dest/$_d"
  done
  mkdir -p "$dest/test"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$dest/test/run.sh"
  chmod +x "$dest/test/run.sh"
}

echo "check: widened ecosystem grep covers lib/, hooks/, git-hooks/, bin/"
mk_kit_copy "$TMP/kc"
out="$(bash "$TMP/kc/bin/check" 2>&1)"; rc=$?
is "clean tree: check exits 0" "0" "$rc"

for d in hooks git-hooks bin; do
  mk_kit_copy "$TMP/kc-$d"
  target="$TMP/kc-$d/$d/$(ls "$TMP/kc-$d/$d" | head -n1)"
  printf '\n# viespeak leaked in here\n' >> "$target"
  out="$(bash "$TMP/kc-$d/bin/check" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && t_ok "ecosystem word planted in $d/ fails check" || t_bad "ecosystem word in $d/" "non-zero" "0"
  printf '%s' "$out" | grep -qi 'viespeak' && t_ok "ecosystem grep reports the hit in $d/" || t_bad "ecosystem grep reports hit" "viespeak" "$out"
done

echo "check: bin/init.mjs and bin/check itself are carved out"
mk_kit_copy "$TMP/kc-carve"
out="$(bash "$TMP/kc-carve/bin/check" 2>&1)"
printf '%s' "$out" | grep -q 'init.mjs' && t_bad "init.mjs not reported (carve-out)" "not reported" "reported" || t_ok "init.mjs not reported (carve-out)"

echo "check: --help"
out="$(bash "$KIT/bin/check" --help 2>&1)"; rc=$?
is "check --help exits 0" "0" "$rc"
printf '%s' "$out" | grep -qi 'gate' && t_ok "check --help prints help text" || t_bad "check --help" "help text" "$out"

echo "check: doctor step is skipped outside a configured workspace, run inside one"
mk_kit_copy "$TMP/kc-nows"
out="$(cd "$TMP" && bash "$TMP/kc-nows/bin/check" 2>&1)"
printf '%s' "$out" | grep -qi 'skipped' && t_ok "no workspace.yml: doctor step reports skipped" || t_bad "doctor skip" "skipped" "$out"

make_multi "$TMP/m"
out="$(cd "$TMP/m" && WORKSPACE_ROOT="$TMP/m" bash "$TMP/kc-nows/bin/check" 2>&1)"
printf '%s' "$out" | grep -qi 'skipped' && t_bad "workspace.yml present: doctor step does NOT skip" "not skipped" "skipped" || t_ok "workspace.yml present: doctor step runs"

finish
