#!/usr/bin/env bash
# Guards the persona layer: every persona skill has frontmatter and points at
# docs/personas/; every stub template carries the ADOPT-ME marker (except the
# README, which describes the layer); the stub set and the skills' references
# stay in agreement. Static — nothing is executed.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PERSONAS="product-analyst business-analyst market-researcher product-owner conversion-audit qa-engineer"

for pskill in $PERSONAS; do
  f="$KIT/skills/$pskill/SKILL.md"
  [ -f "$f" ] || { t_bad "$pskill exists" "$f" "missing"; continue; }
  head -1 "$f" | grep -q '^---$' && t_ok "$pskill: frontmatter opens" || t_bad "$pskill frontmatter" "---" "$(head -1 "$f")"
  grep -q "^name: $pskill\$" "$f" && t_ok "$pskill: name matches directory" || t_bad "$pskill name" "name: $pskill" "$(grep '^name:' "$f")"
  grep -q '^description: Use when' "$f" && t_ok "$pskill: description starts with Use when" || t_bad "$pskill description" "Use when…" "$(grep -c '^description:' "$f") line(s)"
  grep -q 'docs/personas/' "$f" && t_ok "$pskill: reads docs/personas/" || t_bad "$pskill personas ref" "docs/personas/" "none"
  grep -q 'ADOPT-ME' "$f" && t_ok "$pskill: knows the adoption marker" || t_bad "$pskill marker" "ADOPT-ME" "none"
done

for stub in "$KIT"/templates/personas/*.md; do
  base="$(basename "$stub")"
  if [ "$base" = "README.md" ]; then
    grep -q 'ADOPT-ME' "$stub" && t_ok "README explains the marker" || t_bad "README marker" "mentions ADOPT-ME" "none"
    continue
  fi
  head -1 "$stub" | grep -q 'ADOPT-ME' && t_ok "$base: marker on line 1" || t_bad "$base marker" "ADOPT-ME first line" "$(head -1 "$stub")"
done

# Every routed skill carries fixed retrieval probes, so a description edit
# has a suite to rerun instead of a one-off judgment call.
for pskill in $PERSONAS skill-coach; do
  r="$KIT/skills/$pskill/retrieval-samples.md"
  if [ ! -f "$r" ]; then t_bad "$pskill retrieval samples" "$r" "missing"; continue; fi
  grep -q '^## Must route here' "$r" && grep -q '^## Must NOT route here' "$r" \
    && t_ok "$pskill: retrieval samples have both sections" \
    || t_bad "$pskill retrieval sections" "Must route here + Must NOT route here" "$(grep -c '^## ' "$r") section(s)"
  grep -q '” → \|" → ' "$r" && t_ok "$pskill: rejection probes name their target" \
    || t_bad "$pskill rejection targets" 'a "…" → <skill> line' "none"
done

# Every docs/personas/<file> a skill names must exist as a template stub, so
# adoption always has a scaffold to fill.
while IFS= read -r ref; do
  [ -f "$KIT/templates/personas/$ref" ] && t_ok "referenced stub exists: $ref" || t_bad "referenced stub" "templates/personas/$ref" "missing"
done < <(grep -rhoE 'docs/personas/[a-z-]+\.md' "$KIT/skills" | sed 's|docs/personas/||' | sort -u)

finish
