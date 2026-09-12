# Retrieval samples — conversion-audit

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "why aren't users paying?"
- "audit the funnel from install to purchase"
- "is our pricing structured right?"
- "where does the money chain leak?"

## Must NOT route here
- "what's revenue this month? just the number" → product-analyst
- "how do competitors price?" → market-researcher
