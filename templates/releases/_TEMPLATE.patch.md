<!-- OTA-patch note template. Rendered by scripts/release-cut.sh (patch). Do not hand-edit the token placeholders. -->
# {{NAME}} {{VERSION}} — patch {{PATCH_INDEX}} (OTA)

- **Date:** {{DATE}}
- **Base build:** {{VERSION}}
- **Status:** {{STATUS}}

OTA patch stacked on store build `{{VERSION}}`. Dart-only: cherry-picked onto the
released base, leaving any unreleased native work in `develop` untouched. Builds
no new artifact — downloads in the background and applies on next cold launch.

---

## Changelog (internal)

| App commit | Channel | Type | Summary |
| --- | --- | --- | --- |
{{CHANGELOG_ROWS}}

### Release dependencies (must be live before/at rollout)

{{DEPENDENCIES}}

### Verification

- `flutter analyze` clean (patch pre-flight).
- _TODO: cold-launch twice to confirm the patch downloads then applies._
