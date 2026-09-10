#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
make_multi "$TMP/m"; export WORKSPACE_ROOT="$TMP/m"
printf 'API_BASE_URL="https://api.example.test/"\n' > "$TMP/m/my-app/.env.production"
cat >> "$TMP/m/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
  endpoints:
    - path: /health
      expect: '"status"[[:space:]]*:[[:space:]]*"ok"'
    - /api/app/version-status?platform={platform}&build=1
  extra:
    - name: analyzer
      run: "exit 0"
EOF
mkdir -p "$TMP/bin"
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  *"/health") printf '{"status":"ok"}';;
  *"version-status"*) printf '{"ok":true}';;
  *) exit 22;;
esac
EOF
chmod +x "$TMP/bin/curl"; export PATH="$TMP/bin:$PATH"
git -C "$TMP/m/my-app" tag released/1.9.1+76
echo "preflight"
out="$(bash "$KIT/bin/release-preflight" production --mode patch --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "passes" "0" "$rc"
printf '%s' "$out" | grep -q 'Backend: https://api.example.test$' && t_ok "base url from env file, trailing slash trimmed" || t_bad "base url" "https://api.example.test" "$out"
printf '%s' "$out" | grep -q '✓ GET /health -> ok' && t_ok "expect matched" || t_bad "expect matched" "ok" "$out"
printf '%s' "$out" | grep -q '✓ GET /api/app/version-status reachable' && t_ok "reachability check" || t_bad "reachability" "reachable" "$out"
printf '%s' "$out" | grep -q '✓ anchor version matches live released base (1.9.1+76)' && t_ok "version sanity" || t_bad "version sanity" "matches" "$out"
printf '%s' "$out" | grep -q '✓ analyzer clean' && t_ok "extra ran" || t_bad "extra" "clean" "$out"
sed -i.bak 's/exit 0/exit 1/' "$TMP/m/workspace.yml"
out="$(bash "$KIT/bin/release-preflight" production --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "a failing extra fails preflight" "1" "$rc"
printf '%s' "$out" | grep -q 'Pre-flight FAILED' && t_ok "final line" || t_bad "final line" "FAILED" "$out"
rm "$TMP/m/my-app/.env.production"
bash "$KIT/bin/release-preflight" production --skip-doctor >/dev/null 2>&1 && t_bad "missing env file dies" "1" "0" || t_ok "missing env file dies"

echo "preflight: expect present but body does not match -> fail, not ok"
make_multi "$TMP/mismatch"
printf 'API_BASE_URL="https://api.example.test"\n' > "$TMP/mismatch/my-app/.env.production"
cat >> "$TMP/mismatch/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
  endpoints:
    - path: /health
      expect: '"status"[[:space:]]*:[[:space:]]*"ok"'
EOF
git -C "$TMP/mismatch/my-app" tag released/1.9.1+76
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '{"status":"degraded"}'
EOF
chmod +x "$TMP/bin/curl"
out="$(WORKSPACE_ROOT="$TMP/mismatch" bash "$KIT/bin/release-preflight" production --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "a 2xx body that fails expect is a hard failure" "1" "$rc"
printf '%s' "$out" | grep -q '✗ GET /health did not match expect' && t_ok "mismatch reported as a fail, not ok" || t_bad "mismatch" "did not match expect" "$out"
printf '%s' "$out" | grep -q '✓ GET /health -> ok' && t_bad "mismatch must not also print ok" "no ok line" "$out" || t_ok "mismatch must not also print ok"

echo "preflight: a dead endpoint fails but the run continues to the end"
make_multi "$TMP/dead"
printf 'API_BASE_URL="https://api.example.test"\n' > "$TMP/dead/my-app/.env.production"
cat >> "$TMP/dead/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
  endpoints:
    - /down
    - /health
EOF
git -C "$TMP/dead/my-app" tag released/1.9.1+76
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
url="${@: -1}"
case "$url" in
  *"/health") printf '{"status":"ok"}';;
  *) exit 7;;
esac
EOF
chmod +x "$TMP/bin/curl"
out="$(WORKSPACE_ROOT="$TMP/dead" bash "$KIT/bin/release-preflight" production --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "run does not abort mid-check under errexit" "1" "$rc"
printf '%s' "$out" | grep -q '✗ GET /down unreachable' && t_ok "dead endpoint reported unreachable" || t_bad "dead endpoint" "unreachable" "$out"
printf '%s' "$out" | grep -q '✓ GET /health reachable' && t_ok "later endpoints still run after a dead one" || t_bad "later endpoints" "reachable" "$out"
printf '%s' "$out" | grep -q 'Pre-flight FAILED' && t_ok "still reaches the final FAILED line" || t_bad "final line" "FAILED" "$out"

echo "preflight: no endpoints configured at all"
make_multi "$TMP/noep"
printf 'API_BASE_URL="https://api.example.test"\n' > "$TMP/noep/my-app/.env.production"
cat >> "$TMP/noep/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
EOF
git -C "$TMP/noep/my-app" tag released/1.9.1+76
out="$(WORKSPACE_ROOT="$TMP/noep" bash "$KIT/bin/release-preflight" production --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "no endpoints configured still passes" "0" "$rc"
printf '%s' "$out" | grep -q 'Pre-flight passed' && t_ok "final pass line without endpoints" || t_bad "final line" "passed" "$out"

echo "preflight: no extras configured at all"
make_multi "$TMP/noextra"
printf 'API_BASE_URL="https://api.example.test"\n' > "$TMP/noextra/my-app/.env.production"
cat >> "$TMP/noextra/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
  endpoints:
    - /health
EOF
git -C "$TMP/noextra/my-app" tag released/1.9.1+76
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '{"status":"ok"}'
EOF
chmod +x "$TMP/bin/curl"
out="$(WORKSPACE_ROOT="$TMP/noextra" bash "$KIT/bin/release-preflight" production --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "no extras configured still passes" "0" "$rc"
printf '%s' "$out" | grep -q 'Running ' && t_bad "no extras means no Running lines" "none" "$out" || t_ok "no extras means no Running lines"

echo "preflight: two extras, the first fails, the second still runs"
make_multi "$TMP/extras"
printf 'API_BASE_URL="https://api.example.test"\n' > "$TMP/extras/my-app/.env.production"
cat >> "$TMP/extras/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
  extra:
    - name: linter
      run: "echo BOOM; exit 1"
    - name: formatter
      run: "exit 0"
EOF
git -C "$TMP/extras/my-app" tag released/1.9.1+76
rm -rf "${TMPDIR:-/tmp}/agent-workspace-kit"
out="$(WORKSPACE_ROOT="$TMP/extras" bash "$KIT/bin/release-preflight" production --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "a failing extra among several still fails the whole run" "1" "$rc"
printf '%s' "$out" | grep -q '✗ linter reported issues — see' && t_ok "first extra reported as failed" || t_bad "first extra" "reported issues" "$out"
printf '%s' "$out" | grep -q '✓ formatter clean' && t_ok "second extra still ran and passed" || t_bad "second extra" "clean" "$out"
log="${TMPDIR:-/tmp}/agent-workspace-kit/linter.log"
[[ -f "$log" ]] && t_ok "the named log file exists" || t_bad "log file exists" "$log" "missing"
grep -q BOOM "$log" 2>/dev/null && t_ok "the log file holds the failing command's output" || t_bad "log contents" "BOOM" "$(cat "$log" 2>/dev/null)"

echo "preflight: --mode release vs --mode patch against no released tag"
make_multi "$TMP/notag"
printf 'API_BASE_URL="https://api.example.test"\n' > "$TMP/notag/my-app/.env.production"
cat >> "$TMP/notag/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
EOF
out="$(WORKSPACE_ROOT="$TMP/notag" bash "$KIT/bin/release-preflight" production --mode patch --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "patch mode fails with no released tag" "1" "$rc"
printf '%s' "$out" | grep -q 'no released/\* tag exists' && t_ok "patch mode names the missing tag" || t_bad "patch mode" "no released/* tag exists" "$out"
out="$(WORKSPACE_ROOT="$TMP/notag" bash "$KIT/bin/release-preflight" production --mode release --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "release mode does not require a released tag" "0" "$rc"
printf '%s' "$out" | grep -q '✓ release mode — release will bump' && t_ok "release mode reports the bump line" || t_bad "release mode" "release will bump" "$out"

echo "preflight: invalid --mode and invalid env die with the source's messages"
out="$(bash "$KIT/bin/release-preflight" bogus-env --skip-doctor 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -q 'Unknown env: bogus-env (use develop|production)' && t_ok "invalid env dies naming it" || t_bad "invalid env" "Unknown env" "$out"
out="$(bash "$KIT/bin/release-preflight" production --mode bogus-mode --skip-doctor 2>&1 | strip_ansi)" || true
printf '%s' "$out" | grep -q 'Unknown mode: bogus-mode (use patch|release)' && t_ok "invalid mode dies naming it" || t_bad "invalid mode" "Unknown mode" "$out"

echo "preflight: a coupled item in the inventory warns but does not fail the run"
make_multi "$TMP/coupled"; R="$TMP/coupled/my-app"; B="$TMP/coupled/my-be"
git -C "$R" checkout -q develop
printf 'API_BASE_URL="https://api.example.test"\n' > "$R/.env.production"
cat >> "$TMP/coupled/workspace.yml" <<'EOF'
preflight:
  base_url_from: "env:API_BASE_URL@my-app/.env.{env}"
EOF
git -C "$R" tag released/1.9.1+76
c=$(commit_file "$R" lib/core/services/api_service.dart "fix: api")
bc=$(commit_file "$B" src/x.ts "be side")
WORKSPACE_ROOT="$TMP/coupled" bash "$KIT/bin/release-add" "$c" --be "$bc" >/dev/null
out="$(WORKSPACE_ROOT="$TMP/coupled" bash "$KIT/bin/release-preflight" production --skip-doctor 2>&1 | strip_ansi)"; rc=$?
is "a coupled item still lets preflight pass" "0" "$rc"
printf '%s' "$out" | grep -q 'Inventory has coupled item(s)' && t_ok "coupled item produces the warning" || t_bad "coupled warning" "Inventory has coupled" "$out"

finish
