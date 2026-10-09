# Chore Issue: Update dependencies and drop support for Flutter < 3.10

- **Slug**: update-dependencies
- **Fetched**: 2026-10-09
- **Issue**: 3
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/3
- **State**: open
- **Author**: arrrrny
- **Labels**: chore

## Body

## What was asked

Update the package's dependencies — every constraint in `pubspec.yaml` is old and
out of date. Users hit resolver failures (e.g. `hive ^4.0.0-dev.2` conflicts with
`autotrie ^2.0.0 -> hive ^2.0.0`) and HTTP version mismatches against packages
like google_fonts.

Synced from upstream flutter-code-editor (abandoned, forked as zuraffa_code_editor):
- https://github.com/akvelon/flutter-code-editor/issues/314 — "update packages. all are old and out of date"
- https://github.com/akvelon/flutter-code-editor/issues/303 — "Failed to update packages."
- https://github.com/akvelon/flutter-code-editor/issues/253 — "use latest http package"
- https://github.com/akvelon/flutter-code-editor/issues/245 — "Drop support for Flutter < 3.10"

## Why it matters

Dependency rot is the #1 complaint in the upstream issue tracker (3+ issues)
and blocks anyone on a modern Flutter/Hive/HTTP stack from adopting the package.

## Acceptance criteria

- [ ] `flutter pub outdated` shows no avoidable major-version lag for direct dependencies
- [ ] `flutter pub get` resolves cleanly in the example app
- [ ] `dart analyze --fatal-infos` passes after the bumps (no API breakage left behind)
- [ ] Existing test suite still passes after the bumps
- [ ] pubspec sdk constraint reflects the dropped Flutter < 3.10 support

## Comments

None.
