# Retrieval samples — app-store-reviewer

Fixed routing probes for this skill's frontmatter description. Rerun
after ANY edit that touches the description: give a subagent only the
frontmatter descriptions of every skill in `.claude/skills/` plus each
ask below, and have it name the skill it would route to. Every "must
route here" ask must pick this skill; every "must NOT" ask must pick the
skill named after the arrow. A failed probe blocks the edit; if the
skill's scope legitimately moved, update these samples in the same edit.

## Must route here
- "audit the app for anything that would get it rejected by Apple before we submit"
- "kiểm tra xem app có bị Apple reject không trước khi submit"
- "Apple rejected us under guideline 4.8 — what else are they going to flag?"
- "will this paywall pass App Store review?"
- "is our account deletion flow OK by Apple's rules?"
- "can we ship this new tab as an OTA patch, or does it need store review?"
- "draft the App Review notes for App Store Connect"
- "is this build ready to submit to the App Store?"

## Must NOT route here
- "make the App Store screenshots for the new version" → designer
- "test the new feature before we cut the release" → qa-engineer
- "cut the iOS release" → release
- "ship the bug-fix patch to production" → release
- "Apple approved build 2.4.0" → app-live
- "why aren't users paying for premium?" → conversion-audit
- "is the checkout screen's layout right?" → designer
