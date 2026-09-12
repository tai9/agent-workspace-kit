# Retrieval samples — qa-engineer

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "test the feature that was just merged"
- "the bug is fixed — verify it"
- "write a test plan from this spec"
- "what needs testing before we cut this release?"
- "do the client and server still agree on the API shape?"

## Must NOT route here
- "write the acceptance criteria for X" → business-analyst
- "how is the feature doing two weeks post-ship?" → product-analyst
- "is this feature worth shipping?" → product-owner
