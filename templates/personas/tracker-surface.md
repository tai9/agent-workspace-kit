<!-- ADOPT-ME: stub — a persona skill fills this during adoption for this workspace -->
# Tracker surface

Where this workspace's work items live, how to reach them, and the
conventions that make a board readable. Without this file a persona
cannot tell a board that is *wrong* from a board whose conventions it
simply does not know — and cannot write to the board at all, since
Projects v2 writes need node IDs that only adoption records.

Adoption fills:

## Auth

The account a command runs as is decided here, never by `gh`'s
machine-global active login. Record the **auth prefix** every tracker
command must carry — the agent's shell is non-interactive, so a bare
`gh` runs as whatever the keyring holds. Two forms are known to work:

```sh
GH='direnv exec <workspace-root> gh'                      # .envrc decides the account
GH='GH_TOKEN="$(gh auth token --user <login>)" gh'        # the token is named on the command
```

Record: which prefix this workspace uses and why, the **expected
account login** (so `$GH auth status` can be checked against it),
where `.envrc` lives if the first form is used, the SSH host alias if
git uses one, and the scopes the token needs (`repo`, plus `project`
for Projects v2 — `read:project` if this workspace only reads).

Note any `PreToolUse` hook that enforces the prefix, so a denial is
read as the guard working rather than as a broken command.

**Never record a token value here.** `.envrc` belongs in `.gitignore`
and this file is in version control. Widening a token's scope is the
owner's action: `gh auth login/switch/logout/refresh` are never run by
an agent, even when `gh` suggests it — `gh auth switch` in particular
rewrites machine-global state and breaks sessions in other repos.

## Boards — or the absence of one

**First: does this workspace use a Projects v2 board at all?** Many run
on repo issues plus milestones and labels, which is a configuration to
record, not a gap. Say so explicitly here, and name what carries status
instead: which milestone, label, assignee or state means "active", and
what the ordered backlog is read from.

With a board: the org, the project number(s), which is authoritative
when there is more than one, and what each is for.

Board writes need node IDs. Capture them once, here:

```sh
$GH project view <n> --owner <org> --format json --jq .id      # project-id
$GH project field-list <n> --owner <org> -L 50 --format json   # field ids + option ids
```

| Field | Field ID | Option | Option ID |
| --- | --- | --- | --- |

(Item IDs are per-item and come from `gh project item-list --format json`.)

## Repos with their own issues

Which repos in `workspace.yml` carry issues, and whether issues living
off the board are deliberate.

| Repo | Issues used | On the board? | Notes |
| --- | --- | --- | --- |

## Conventions

- **Field meanings** — what each Status/Priority/Size value actually
  means here, mapped onto the persona's ladders if the names differ.
- **Label conventions** — the vocabulary, what each label means, which
  ones are load-bearing for automation.
- **Definition of done** — what must be true before an item is closed:
  merged, or released? Who closes it? This answer governs every Close
  a persona makes; where done means released, merged work moves to the
  shipped-pending status instead.
- **Stale threshold** — after how many days without a commit, PR or
  comment an in-progress item is treated as stalled, and who gets
  pinged.
- **Cadence** — sprint/cycle length if any, when the board is
  reviewed, milestone naming, and how milestones map to releases.
- **Scale** — roughly how many open and closed issues exist, so a
  persona scopes its pulls instead of sweeping. Snapshots land in a
  gitignored `.pm-cache/`.
- **Known traps** — dated: stale items nobody will close, a second
  tracker some work lives in, a label everyone ignores, work that
  routinely happens with no issue at all.
