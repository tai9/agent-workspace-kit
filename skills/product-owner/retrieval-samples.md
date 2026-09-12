# Retrieval samples — product-owner

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "should we build feature X?"
- "what should we build next quarter?"
- "keep, iterate, or kill feature Y?"
- "what's the smallest version of X worth shipping?"

## Must NOT route here
- "write the requirements for X" → business-analyst
- "what's the actual number for Y?" → product-analyst
- "does the build match the spec?" → qa-engineer
