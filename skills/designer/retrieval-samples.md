# Retrieval samples — designer

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "design the new progress screen"
- "does the paywall screen look right?"
- "are colors and fonts consistent across our surfaces?"
- "how do other apps design their onboarding screens?"
- "the scorecard screen is built — compare it to the design"
- "is this button label and error message right?"
- "make the App Store screenshot set"

## Must NOT route here
- "what features and pricing do our competitors have?" → market-researcher
- "test the feature that was just built" → qa-engineer
- "should we build this screen at all?" → product-owner
- "write the requirements for screen X" → business-analyst
- "why don't users tap the buy button?" → conversion-audit
