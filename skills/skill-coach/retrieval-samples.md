# Retrieval samples — skill-coach

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "the analyst skill quoted a stale price — update the skill"
- "skill X used the wrong method, make the lesson stick"
- "that answer broke a skill rule — strengthen the skill so it doesn't recur"

## Must NOT route here
- "create a brand-new skill for X" → a skill-authoring workflow, not this skill
- "fix the product bug the skill found" → feature work, not this skill
