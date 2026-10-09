# Chore Assessment: Update dependencies and drop support for Flutter < 3.10

- **Slug**: update-dependencies
- **Created**: 2026-10-09
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/3
- **Verdict**: do it
- **Size**: small

## Report (verbatim or summarized)

Upstream reports (314, 303, 253, 245): every constraint is "old and out of
date"; users hit resolver failures (autotrie→hive, http mismatch) and ask to
drop Flutter < 3.10.

## Summary

The fork's repackage already carried most bumps. `flutter pub outdated`
(2026-10-09) leaves a small, well-defined remainder:

| Package | Current | Target | Kind |
|---------|---------|--------|------|
| url_launcher | 6.3.2 | 6.3.3 | patch |
| equatable | 2.1.0 | 3.0.0 | major |
| material_color_utilities (transitive) | 0.13.0 | 0.13.1 | patch, rides along |
| test_api (transitive) | 0.7.12 | 0.7.15 | patch, rides along |

Plus the environment floor: `sdk: ">=2.17.0 <4.0.0"`, `flutter: ">=3.0.0"` →
drop Flutter < 3.10 (upstream #245) and remove the compat workaround in
`lib/src/gutter/gutter.dart` (TODO + `ignore_for_file:
unnecessary_non_null_assertion`).

## Constitution Check

No `.specify/constitution.md` exists in this repo — nothing to check against.
The change is maintenance-only and preserves public API, which is the least
controversial class of chore.

## Affected Paths

- `pubspec.yaml` — constraints above.
- `lib/src/**` — equatable 2→3 fallout only. Audit found **no `stringify`
  overrides** anywhere in `lib/` or `example/`; all 11 equatable users rely on
  the stable `Equatable`/`EquatableMixin` + `props` API, which is unchanged in
  3.x. Expect zero or near-zero code changes.
- `lib/src/gutter/gutter.dart` — remove the Flutter < 3.10 TODO + compat ignore
  once the floor moves (verify `dart analyze --fatal-infos` stays clean without
  it; the file's `!` assertions are gone, so the ignore should be droppable).
- `example/pubspec.yaml` — keep the example's Flutter floor consistent.

## Proposed Approach

1. `pubspec.yaml`: `url_launcher: ^6.3.3`, `equatable: ^3.0.0`,
   `environment: sdk ">=3.0.0 <4.0.0", flutter ">=3.10.0"`.
   (Dropping Flutter < 3.10 implies Dart ≥ 3.0, which is equatable 3's floor
   too; confirm during resolution.)
2. `flutter pub get`; resolve fallout (expect none in lib; check example).
3. Remove the gutter.dart compat header if analyze stays clean.
4. Verify: `dart analyze --fatal-infos`, `dart format --set-exit-if-changed .`,
   `flutter test`.

## Risks & Considerations

- equatable major bump is the only semver-risk; mitigated by the stringify audit.
- Raising the SDK floor drops Dart 2.x consumers — intended (upstream #245) and
  announced via the issue.
- CI (`.github/workflows/dart.yaml`) pins Flutter 3.19.6 — still fine, but the
  separate CI/coverage effort should widen the matrix afterwards.

## Open Questions

- None.
