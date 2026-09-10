<!-- Store-release note template. Rendered by scripts/release-cut.sh (release). Do not hand-edit the token placeholders. -->
# {{NAME}} {{VERSION}} — store release

- **Date:** {{DATE}}
- **App version:** {{VERSION}}
- **Status:** {{STATUS}}

### Ship plan

Store release (new build number). Carries forward any 🟢 OTA items listed below
to fresh installs; existing users on the previous build received the OTA items
as patches.

---

## Promotional Text (store copy)

> App Store Connect → "Promotional Text". Max **170 characters**, shown above the
> description, and editable without a new review — so it can be refreshed between
> releases. Vietnamese first, then English. Lead with the headline benefit of this
> build. Required on every store release — do not leave the TODOs.

### Tiếng Việt (…/170)

_TODO: một câu bán hàng, tối đa 170 ký tự._

### English (…/170)

_TODO: one selling sentence, max 170 characters._

---

## What's new (store copy)

> User-facing, Vietnamese first then English. Short, benefit-led, no jargon or
> commit hashes. Paste into App Store Connect / Play Console "What's New".

### Tiếng Việt

- _TODO: viết nội dung cho người dùng._

### English

- _TODO: write user-facing copy._

---

## Changelog (internal)

| App commit | Channel | Type | Summary |
| --- | --- | --- | --- |
{{CHANGELOG_ROWS}}

Channel legend: 🟢 OTA = Dart-only (ships via Shorebird patch) · 🔴 Store =
native change (store release + an `app_versions.min_build` bump when older builds
must not run against it).

### Release dependencies (must be live before/at rollout)

{{DEPENDENCIES}}

### Verification

- `flutter analyze` clean (release pre-flight).
- _TODO: on-device / staging confirmation, store processing._

### Scope

- _TODO: platforms covered; any follow-ups (e.g. Android parity, min_build bump)._
