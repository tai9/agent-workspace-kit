# Retrieval samples — business-analyst

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "what would it take to improve retention — clarify the problem"
- "how does the signup flow actually work today?"
- "write the requirements and user stories for feature X"
- "which repos and contracts does this change touch?"

## Must NOT route here
- "which of these should we build first?" → product-owner
- "what's the churn number?" → product-analyst
- "write a test plan for this spec" → qa-engineer
