<!-- ADOPT-ME: stub — a persona skill fills this during adoption for this workspace -->
# Data access

How to actually get numbers in this workspace, read-only. Until adopted,
no persona skill may quote a production number.

Adoption fills, with runnable shapes (commands with env sourced, never
secrets in argv or output):

## Analytics store
- What it is (product analytics tool, project/instance), where the
  read-capable credentials live, and the query shape that works.
- How internal/test users are filtered, exactly — and the failure mode of
  getting the filter backwards.
- Events emitted from more than one side (client + server): how they are
  disambiguated, and the sweep query that regenerates the current list.

## Production database
- The read paths, best first (an RPC layer, a REST layer, a console) and
  what each cannot express.
- The tables that hold money, users, sessions, and content.
- Ready-made queries/RPCs/dashboards that already answer common
  questions — reuse beats re-deriving, and keeps numbers consistent with
  what the team already looks at.

## Joining the two
- The join key between analytics identity and database identity, and its
  known gaps (pre-signup identity, un-identified events).

## Known counting traps
- The mistakes that have already produced a wrong headline number here,
  each with the guard query.
