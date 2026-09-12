<!-- ADOPT-ME: stub — a persona skill fills this during adoption for this workspace -->
# Test surface map

What test infrastructure exists in this workspace, how to run it, and
where the known holes are. **Stale-by-design**: entries describe the
surface as of their date; when an engagement finds it has moved, update
the entry.

Adoption fills, per repo:

| Repo | Run | What it is | CI on PR |
| --- | --- | --- | --- |

And records:

- **Environments** — which are safe to write to (dev/staging), which are
  read-only (production, always), and the test accounts (tier + where
  credentials live — a gitignored env file, never values in this doc).
- **Suite landmines** — pre-existing failures that are not regressions
  (named, so a red run can be read), flaky tests, mock-only coverage
  areas, tooling traps.
- **Emulator/device divergence** — what the emulator cannot genuinely
  test (sensors, native dialogs, purchases, push), so the human/agent
  split has a factual basis.
- **Evidence tools** — the error tracker and analytics used for bug
  repro, and version-specific traps (e.g. builds without crash symbols).
- **Known gaps and their triggers** — automation the workspace lacks,
  each with the condition under which adopting it should be proposed to
  product-owner (e.g. "a second shipped bug in class X", "manual pass
  exceeds N minutes per release").
