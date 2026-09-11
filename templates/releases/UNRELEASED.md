# Unreleased — {{NAME}} app

What is queued and what is live, and nothing else. This file is read before
every ship, so it stays short on purpose. A rule that holds for every release
belongs in `RELEASE_PROCESS.md`; anything true only of one release belongs in
that release's own note under `releases/`. The workspace doctor fails this
file when the prose around the tables grows back.

_Last updated: never_

## Live now

One row per ship target (a store, a channel, an environment). Fill it at each
go-live; it is the answer to "what are users actually running".

<!-- STATE:START -->
| Target | Shipped build | OTA base | Live since |
| ------ | ------------- | -------- | ---------- |
| — | — | — | — |

- **Mirror ref:** —
- **Next action:** —
<!-- STATE:END -->

## Queued

Items merged into `{{TRUNK}}` but not yet shipped. `release add` appends a row
here on each squash-merge; `release cut` moves the picked rows out into a
versioned store note (`<version>.md`) or a patch note
(`<live-version>.patchN.md`).

| # | Channel | Type | Summary | App commit | BE commit | Coupled |
| - | ------- | ---- | ------- | ---------- | --------- | ------- |
<!-- ITEMS:START -->
<!-- ITEMS:END -->

## Open decisions

One line each, dated. Delete the line the moment it is resolved. If it needs a
paragraph to explain, it is not a decision — it is a rule (`RELEASE_PROCESS.md`)
or a release fact (the release note).

- _none_
