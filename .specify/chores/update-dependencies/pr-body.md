## Summary

Bumps the remaining outdated dependencies and drops the Flutter < 3.10 support
floor. Consolidates upstream reports
[#314](https://github.com/akvelon/flutter-code-editor/issues/314),
[#303](https://github.com/akvelon/flutter-code-editor/issues/303),
[#253](https://github.com/akvelon/flutter-code-editor/issues/253),
[#245](https://github.com/akvelon/flutter-code-editor/issues/245).

## Changes

| File | Change |
|------|--------|
| `pubspec.yaml` | equatable 2.1.0 → 3.0.0, url_launcher 6.3.2 → 6.3.3, sdk `>=3.0.0 <4.0.0`, flutter `>=3.10.0` |
| `example/pubspec.yaml` | sdk floor aligned |
| 8 lib files (folding, code, named_sections, history, hidden_ranges) | `with EquatableMixin` → `with Equatable` (removed in equatable 3.0.0) |
| `lib/src/folding/foldable_block.dart` | two enum switches rewritten as equality checks (exhaustiveness on modern SDKs) |

## Verification

- `flutter test` → **All 295 tests pass**
- `dart analyze --fatal-infos` → no errors/warnings; 16 pre-existing info-level
  deprecations remain (identical set minus the equatable ones on master; those
  belong to the planned CI-alignment chore)
- `flutter pub get` resolves cleanly in package + example

## Notes

- `lib/src/gutter/gutter.dart`'s Flutter < 3.10 compat header is intentionally
  kept: its `children!` assertions are load-bearing on older supported Flutters.
- Pre-existing `dart format` drift in `lib/src/code/code.dart` and
  `test/src/folding/folded_closing_line_test.dart` also exists on master; left
  for the CI-alignment chore to avoid mixing concerns.

Assessment: `.specify/chores/update-dependencies/assessment.md`
Implementation report: `.specify/chores/update-dependencies/implement.md`

Closes #3
