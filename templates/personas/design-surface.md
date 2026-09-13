<!-- ADOPT-ME: stub — a persona skill fills this during adoption for this workspace -->
# Design surface map

The product's design system as it actually exists — token sources of
truth, brand canon, typography traps, component inventory, and capture
tooling. **Stale-by-design**: entries describe the surface as of their
date; when an engagement finds it has moved, update the entry.

Adoption fills:

- **Brand canon** — the accent color (there is one), the neutral family,
  the canvas, and the brand's named identity if it has one. This is what
  the anti-slop "one accent, locked" law locks to.
- **Token sources of truth, in rank order** — the canonical token file
  first, then each surface's mirror (app theme files, site CSS
  variables). Job 3 (design-system audit) diffs the mirrors against the
  canonical source. Record the call-site law if the repo has one (e.g.
  "no raw hex outside the token files").
- **Scales** — spacing base unit and named steps; the radius scale
  including deliberate off-scale values (off-grid ≠ drift when the
  token is named).
- **Typography** — families as *registered* (exact string), known glyph
  gaps and tofu traps, test-environment font gotchas.
- **Component inventory** — where shared components live, so specs reuse
  before inventing. Point at directories rather than duplicating lists
  that go stale.
- **Capture tooling** — how to screenshot and screen-record each
  platform (emulator commands, deep-link tricks, what doesn't work), so
  the L2/L3 evidence layers have a factual basis.
- **Store & marketing surfaces** — the store-metadata source of truth,
  where marketing assets live, and which surfaces deploy on merge.
- **Decided norms (don't re-flag)** — design decisions the owner made on
  purpose that a review must not re-litigate.
- **Worked examples** — finished reviews and specs, path + one line
  each, so the next engagement starts from precedent.
