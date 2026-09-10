---
name: app-live
description: Mark a store build as actually live after review passes — update the release note status, push the released/<version> tag, merge that tag into the mirror branch, and run the project's post_release commands. Use when the user says a build was approved / is live / "app đã lên sóng" / "Apple duyệt rồi", or types /app-live <version>.
---

# App is live — post-review updates

The last step of a store release, the one `release cut` deliberately does
**not** do: a build is only "live" once the store(s) have approved and/or
rolled it out, which happens hours-to-days after the cut. This skill moves
the things that must move at that moment.

Full process: `releases/RELEASE_PROCESS.md`. Cutting the release itself is the
`release` skill — this one runs **after** it.

Everything goes through `agent-workspace-kit live`; **do not hand-edit the
release note, the tag, the mirror branch, or anything a `post_release`
command would touch.** Run from the workspace root (the directory holding
`workspace.yml`, `releases/`, and the repos/role directories it names — see
`workspace.yml` for which repo is "the anchor repo" and which branch is "the
mirror branch").

## What "live" moves

| # | Target | Why it is here and not in the cut |
| --- | --- | --- |
| 1 | `releases/<version>.md` → `Status: live <date> — iOS ✅ · Android ⏳` | The note is written at cut time with `released <date>`; only now is it true that users have it. |
| 2 | `released/<version>` tag pushed to origin | The OTA patch baseline. A production release with no pushed tag is not a release. |
| 3 | the anchor's mirror branch ← merge the **`released/<version>` tag** | The mirror branch mirrors what users are running. |
| 4 | the project's configured `post_release` commands | Whatever the workspace needs to move at go-live — e.g. a version gate — without the kit knowing what that is. |

## Steps

1. **Resolve the version.** Use the argument (`/app-live 1.9.0+75`). If none
   was given, ask for it — `agent-workspace-kit live` requires an explicit
   `<version>` and validates it looks like `1.9.0+75`.
2. **Resolve the platform.** Default `both`. If the user says only one store
   approved ("iOS duyệt rồi", "Play chưa rollout"), pass `--platform ios` or
   `--platform android`. Re-running later for the other store is expected and
   converges — the note keeps the first platform's ✅.
3. **Report first, always** (read-only, no confirmation needed):

   ```sh
   agent-workspace-kit live <version> [--platform ios|android|both]
   ```

   With no other flags this only reports and changes nothing. Relay it: note
   found + whether store copy TODOs remain, tag state, how far the mirror
   branch is behind the tag, how far the anchor trunk is *ahead* of it, and
   the resolved `post_release` commands it would run.
4. **Get an explicit go-ahead in the same turn before any write.** Show the
   plan from the report and name the side effects: a push to the mirror
   branch and whatever the `post_release` commands do. A status question
   ("app live rồi đúng không?", "kiểm tra xem") is read-only — answer with
   the report and stop.
5. **Apply** once told to:

   ```sh
   agent-workspace-kit live <version> [--platform …] --apply --merge-mirror --post
   ```

   - `--apply` alone = note status + tag push (local/repo only).
   - `--post` adds the `post_release` commands (implies `--apply`); pass
     `--post-args "<str>"` if the user wants to forward extra arguments into
     them.
   - `--merge-mirror` adds the merge into the mirror branch and the push
     (implies `--apply`).
6. **Relay the leftovers** the command prints: any per-repo tag the anchor's
   ship step doesn't create automatically, unfilled What's new / Promotional
   Text, and any tracker status.

## Guardrails

- **Merge the tag, never the anchor trunk.** The anchor trunk runs ahead of
  the shipped build (the report prints by how many commits); merging it would
  put unshipped code on the branch that is supposed to mirror the stores. The
  command does this correctly — do not "help" by merging the trunk.
- **The mirror branch only moves when both stores are live.** With one
  platform live the command skips the merge by design; `--force-merge` exists
  but needs the user to ask for it.
- **The `post_release` commands run for real** once `--post` is passed —
  they are whatever the project configured (e.g. a version-gate bump against
  a real environment). The report prints the resolved command lines; show
  them to the user before applying.
- The gate a `post_release` command enforces is never lowered by this skill —
  that is the command's own job, not something to work around here.
- Every remote git action in the anchor repo runs through that repo's own env
  (e.g. `direnv`, so the right account/token is used) — the command handles
  this itself; don't bypass it.
- Re-running is safe. Each step checks its own state first and no-ops if
  done.
