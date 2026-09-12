# Retrieval samples — product-analyst

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "what's our DAU this week?"
- "why did this metric drop?"
- "how should we measure feature X — which events do we need?"
- "how many users complete onboarding? build the funnel"
- "feature Y shipped two weeks ago — how is it doing against its kill criteria?"

## Must NOT route here
- "should we build feature X?" → product-owner
- "why don't users pay?" → conversion-audit
- "test the feature that just merged" → qa-engineer
