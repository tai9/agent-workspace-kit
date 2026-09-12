# Retrieval samples — market-researcher

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "tear down competitor X's product"
- "how do competitors price their subscriptions?"
- "scan the market for apps doing Y"
- "what does competitor X's onboarding look like?"

## Must NOT route here
- "why don't our own users convert?" → conversion-audit
- "should we copy competitor feature X?" → product-owner
