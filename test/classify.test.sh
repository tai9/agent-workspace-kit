#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
make_multi "$TMP/m"; WORKSPACE_ROOT="$TMP/m"
source "$KIT/lib/out.sh"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"; source "$KIT/lib/classify.sh"
R="$TMP/m/my-app"
echo "Classification — OTA vs Store"
c=$(commit_file "$R" lib/features/home/home_screen.dart "dart only")
is "a Dart-only commit is OTA"                 "OTA"   "$(classify_commit app "$c")"
c=$(commit_file "$R" android/app/src/main/kotlin/MainActivity.kt "native source")
is "anything under android/ is Store"          "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$R" ios/Runner/AppDelegate.swift "native source")
is "anything under ios/ is Store"              "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$R" macos/Runner/Info.plist "plist")
is "an Info.plist change is Store"             "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$R" build.gradle "gradle at the root")
is "a .gradle change is Store"                 "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$R" assets/images/hero.png "asset")
is "any touch under assets/ is Store"          "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$R" assets/anim/cheer.json "lottie")
is "a changed asset is Store whatever its extension" "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$R" pubspec.yaml "dep bump")
is "a pubspec change is Store"                 "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$R" test/features/home/home_test.dart "test only")
is "a test-only commit is OTA"                 "OTA"   "$(classify_commit app "$c")"
c=$(commit_file "$R" lib/myassets/x.dart "not an assets dir")
is "assets must be a path segment"             "OTA"   "$(classify_commit app "$c")"
is "the regex matches VieSpeak's" 'android/|ios/|pubspec|\.gradle|Podfile|Info\.plist|AndroidManifest|(^|/)assets/' "$(store_regex)"
c=$(commit_file "$R" ANDROID/Foo.kt "shouty native path")
is "classification is case-insensitive" "STORE" "$(classify_commit app "$c")"

echo "Coupling heuristic"
c=$(commit_file "$R" lib/core/services/api_service.dart "api client")
commit_looks_coupled app "$c" && t_ok "touching api_service looks coupled" || t_bad "touching api_service looks coupled" "coupled" "not coupled"
c=$(commit_file "$R" lib/features/shop/shop_screen.dart "unrelated screen")
commit_looks_coupled app "$c" && t_bad "an unrelated screen is not coupled" "not coupled" "coupled" || t_ok "an unrelated screen is not coupled"

echo "Commit metadata"
c=$(commit_file "$R" lib/x.dart "feat(shop): add cart")
is "type" "feat" "$(commit_type app "$c")"
is "summary strips the prefix" "add cart" "$(commit_summary app "$c")"
c=$(commit_file "$R" lib/y.dart "Plain subject")
is "no prefix falls back to chore" "chore" "$(commit_type app "$c")"
is "short hash is 12 hex chars" "1" "$(commit_short app "$c" | grep -qE '^[0-9a-f]{12}$' && echo 1 || echo 0)"
c=$(commit_file "$R" "lib/z.dart" "feat(api)!: drop v1")
is "type with scope and breaking bang" "feat" "$(commit_type app "$c")"
is "summary with scope and breaking bang" "drop v1" "$(commit_summary app "$c")"
c=$(commit_file "$R" "lib/w.dart" "fix: keep the | in tables intact")
is "summary keeps a markdown pipe intact" "keep the | in tables intact" "$(commit_summary app "$c")"

echo "monorepo scoping"
make_mono "$TMP/o"; WORKSPACE_ROOT="$TMP/o"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"
c=$(commit_file "$TMP/o" backend/android/x "backend dir named android");
is "another role's files do not classify the anchor" "OTA" "$(classify_commit app "$c")"
c=$(commit_file "$TMP/o" app/ios/Runner.swift "app native")
is "the anchor's own native change is Store" "STORE" "$(classify_commit app "$c")"

echo "no store_paths configured"
mkdir -p "$TMP/n/thing"; git_init "$TMP/n/thing"
cat > "$TMP/n/workspace.yml" <<'EOF'
name: NoStore
shape: multi-repo
repos:
  app: { path: thing, trunk: main, role: release-anchor }
release:
  adapter: flutter-shorebird
  anchor_file: thing/pubspec.yaml
  tag: "released/{version}"
EOF
WORKSPACE_ROOT="$TMP/n"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"
is "store_regex is empty when store_paths is absent" "" "$(store_regex)"
c=$(commit_file "$TMP/n/thing" android/x.kt "would be store under the other fixture")
is "with no store_paths configured, everything classifies OTA" "OTA" "$(classify_commit app "$c")"

echo "no contract_paths configured"
c=$(commit_file "$TMP/n/thing" lib/core/services/api_service.dart "same path the other fixture treats as coupled")
commit_looks_coupled app "$c" && t_bad "no contract_paths means nothing is coupled" "not coupled" "coupled" || t_ok "no contract_paths means nothing is coupled"

echo "store path entries with non-dot regex metacharacters"
mkdir -p "$TMP/p/thing2"; git_init "$TMP/p/thing2"
cat > "$TMP/p/workspace.yml" <<'EOF'
name: Meta
shape: multi-repo
repos:
  app: { path: thing2, trunk: main, role: release-anchor }
release:
  adapter: flutter-shorebird
  anchor_file: thing2/pubspec.yaml
  tag: "released/{version}"
  store_paths: ["Runner+Extension", "a[b]c"]
EOF
WORKSPACE_ROOT="$TMP/p"; source "$KIT/lib/config.sh"; source "$KIT/lib/repos.sh"
is "only dots are escaped; other metacharacters pass through as regex" 'Runner+Extension|a[b]c' "$(store_regex)"
c=$(commit_file "$TMP/p/thing2" "Runner+Extension/x" "native extension file, literal +")
is "grep -E does not blow up, but an unescaped + is a quantifier, not literal, so this does not match" "OTA" "$(classify_commit app "$c")"
c=$(commit_file "$TMP/p/thing2" "RunnerExtension/x" "no literal plus: matches because + means one-or-more of the preceding r")
is "the + quantifier still matches the no-plus variant" "STORE" "$(classify_commit app "$c")"
c=$(commit_file "$TMP/p/thing2" "abc" "matches a[b]c as a character class, not literally")
is "an unescaped character class matches what the class means, not the literal string" "STORE" "$(classify_commit app "$c")"

finish
