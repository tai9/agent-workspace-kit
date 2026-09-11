<!-- ADOPT-ME: stub — a persona skill fills this during adoption for this workspace -->
# Flow map

Where each major product flow lives: the code that implements it, the
state that persists it, and the contract it sits inside. A **map, not a
source of truth** — code and tables at the destination win over anything
summarized here.

Adoption fills one row per flow the product actually has (signup,
core-usage loop, purchase/entitlement, notifications, upgrade/version
gate, and the product's own feature flows):

| Flow | Repos/dirs | Key code & docs | State (tables) | Contract / gotchas |
| --- | --- | --- | --- | --- |

Also record the two standing traps, with this workspace's examples:

1. **Deliberately-removed behaviour** — features taken out on purpose,
   so an as-is analysis doesn't resurrect them as "gaps".
2. **Display-only vs enforced** — rules whose UI half and server half
   have drifted, and which side is authoritative.
