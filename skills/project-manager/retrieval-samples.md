# Retrieval samples — project-manager

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

The live boundary is with `product-owner`: value questions are theirs,
execution questions are this skill's. Most of the rejection probes below
guard that line.

## Must route here
- "what's the status of the project right now?"
- "which issues are blocked and why?"
- "what should I work on next?"
- "triage these new issues — how complex and how urgent are they?"
- "are we going to make the milestone?"
- "the board doesn't match reality, clean it up"
- "move #42 to In Progress and assign it to me"
- "is #42 a duplicate of #17?"
- "how complex is this issue really — is it an XS or an L?"
- "what order should we solve these five issues in?"

## Must NOT route here
The first four are the live collisions — each is phrased the way the
neighbouring skill's own description phrases it, so an easy probe would
pass while the real overlap still leaked.

- "what's the priority — which of these bets do we fund next?" → product-owner
- "should we build feature X at all?" → product-owner
- "keep, iterate, or kill feature Y?" → product-owner
- "is #42 ready?" (meaning: does the build satisfy the AC) → qa-engineer
- "which repos and contracts does this change touch, for the spec?" → business-analyst
- "how many repos does this change touch?" → business-analyst (asking *what it
  touches* is scoping for a spec; asking *how big it is* is sizing, and stays
  here — the two were one probe until a run split them)
- "write the requirements for this issue" → business-analyst
- "how is feature X doing since we shipped it?" → product-analyst
- "how many users hit this flow last week?" → product-analyst
- "cut a patch release for staging" → release
- "what's merged but not shipped?" → release
