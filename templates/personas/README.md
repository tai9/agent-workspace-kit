# Persona references — workspace-owned

The kit's persona skills (product-analyst, business-analyst,
market-researcher, product-owner, conversion-audit, qa-engineer) carry
the *method*:
jobs, disciplines, output shapes. What they cannot carry is *this
workspace* — its metrics, flows, strategy, market, and how to query its
data. That knowledge lives here, in files this workspace owns and the
skills read.

Every file in this directory starts life as a stub carrying an
`ADOPT-ME` marker. A persona skill that needs a file and finds the
marker (or no file at all) runs **adoption** first: it explores the
workspace — rules file, `workspace.yml`, code, data access — interviews
the owner with structured questions, fills the file, and removes the
marker. Only then does it do the job it was asked. Adoption is
incremental: each engagement fills only the files it needs.

| File | Owned knowledge | Primary consumers |
| --- | --- | --- |
| `data-access.md` | How to query this workspace's analytics store and production database, read-only; the ready-made queries and their traps | product-analyst, conversion-audit, business-analyst |
| `metrics-catalog.md` | Canonical metric definitions and each one's source of truth | product-analyst |
| `prior-findings.md` | What has been measured, tried, reverted, or deliberately decided; which recorded numbers are stale | all personas |
| `flow-map.md` | Where each major product flow lives: code, state, contracts, gotchas | business-analyst, conversion-audit |
| `product-strategy.md` | North star, ICP, moat, hard constraints, standing risks | product-owner |
| `market-landscape.md` | The competitor roster and what is known about each, dated | market-researcher |
| `domain-playbook.md` | Domain reasoning the generic playbooks can't know: the local market, benchmarks, what converts in this product's category | conversion-audit, market-researcher, product-owner |
| `test-surface.md` | Test suites per repo and how to run them, environments and test accounts, suite landmines, emulator/device divergence, automation gaps with adoption triggers | qa-engineer |

These are living documents. Skills that learn something durable during an
engagement update the relevant file; findings that expire (a competitor
fact, a measured baseline) carry dates so staleness is visible. Keep the
directory in version control — it is product knowledge, not scratch.
