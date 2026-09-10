#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "plugin.json: no ecosystem-specific keywords (consistency with the earlier ruling)"
kws="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).keywords.join(" "))' "$KIT/.claude-plugin/plugin.json")"
case " $kws " in
  *" flutter "*|*" shorebird "*|*" dart "*|*" pubspec "*|*" supabase "*)
    t_bad "keywords carry no ecosystem name" "none of flutter/shorebird/dart/pubspec/supabase" "$kws" ;;
  *) t_ok "keywords carry no ecosystem name" ;;
esac

echo "README.md: status line is current, and release cut's flags are all documented"
readme="$KIT/README.md"
grep -qi 'not yet implemented' "$readme" && t_bad "README no longer says 'not yet implemented'" "absent" "present" || t_ok "README no longer says 'not yet implemented'"
for flag in "\-\-commits" "\-\-base" "\-\-at" "\-\-allow-asset-diffs"; do
  grep -q "$flag" "$readme" && t_ok "README documents $flag" || t_bad "README documents $flag" "present" "missing"
done

finish
