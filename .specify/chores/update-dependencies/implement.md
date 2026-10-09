# Chore Implementation: Update dependencies and drop support for Flutter < 3.10

- **Slug**: update-dependencies
- **Implemented**: 2026-10-09
- **Assessment**: ./assessment.md
- **Status**: applied

## Summary

Bumped the remaining outdated dependencies (equatable 2.1.0 → 3.0.0,
url_launcher 6.3.2 → 6.3.3), dropped the Flutter < 3.10 floor (sdk → Dart 3.0),
and resolved the equatable 3 fallout. Closes upstream reports 314/303/253/245.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `pubspec.yaml` | modified | equatable ^3.0.0, url_launcher ^6.3.3, sdk ">=3.0.0 <4.0.0", flutter ">=3.10.0" |
| `example/pubspec.yaml` | modified | sdk floor aligned to >=3.0.0 <4.0.0 |
| `lib/src/folding/foldable_block.dart` | modified | EquatableMixin → Equatable; two enum switches → equality expressions |
| `lib/src/folding/invalid_foldable_block.dart` | modified | EquatableMixin → Equatable |
| `lib/src/code/code_lines.dart` | modified | EquatableMixin → Equatable |
| `lib/src/named_sections/named_section.dart` | modified | EquatableMixin → Equatable |
| `lib/src/history/code_history_record.dart` | modified | EquatableMixin → Equatable |
| `lib/src/hidden_ranges/line_numbering_breakpoint.dart` | modified | EquatableMixin → Equatable |
| `lib/src/hidden_ranges/hidden_line_ranges.dart` | modified | EquatableMixin → Equatable |
| `lib/src/hidden_ranges/hidden_range.dart` | modified | EquatableMixin → Equatable |

## Diff Highlights (optional)

equatable 3.0.0 removed `EquatableMixin`; the supported pattern is
`class X with Equatable`. The two switch statements in `foldable_block.dart`
used `// ignore: missing_enum_constant_in_switch` and now trip
`non_exhaustive_switch_statement` on modern SDKs; rewritten as:

```dart
bool get isComment =>
    type == FoldableBlockType.singleLineComment ||
    type == FoldableBlockType.multilineComment;
bool get isImports => type == FoldableBlockType.imports;
```

Behavior identical; the `// ignore` comments and dead trailing `return false`
blocks are gone.

`lib/src/gutter/gutter.dart`'s Flutter < 3.10 compat header was **kept**: the
`children!` assertions it silences are required on older supported Flutters
(TableRow.children only became non-nullable in newer framework versions), so
removing it would break the 3.10–3.18 range the floor now declares.

## Verification

- `dart analyze --fatal-infos` → no errors, no warnings. 16 info-level
  deprecations remain, all pre-existing on master (withOpacity/onBackground/
  color component getters, `use_key_in_widget_constructors`, whereNotNull) and
  unrelated to this bump.
- `dart format --output=none --set-exit-if-changed .` → 2 files changed
  (`lib/src/code/code.dart`, `test/src/folding/folded_closing_line_test.dart`),
  verified identical drift on master — pre-existing, left for the CI-alignment
  chore.
- `flutter pub get` → resolves cleanly in both package and example.
- `flutter test` → running at time of writing (see PR checks).

## Deviations from Assessment

- The assessment proposed removing the `gutter.dart` compat header; analysis
  showed the `!` assertions are load-bearing for Flutter < the version where
  `TableRow.children` became non-nullable, so the header stays. Deviation
  recorded rather than silently changing the plan.
- `foldable_block.dart` switch rewrite was not foreseen in the assessment; it is
  fallout the equatable/modern-SDK analysis surfaced and is included here
  because it is the same file family the bump touched.
- material_color_utilities/test_api patch bumps (transitive) were not applied:
  they are pinned by the flutter_test SDK constraint and ride along later.

## Follow-ups

- File + implement the CI-alignment chore: fix the 2 pre-existing format
  drifts, decide on the 16 analyze infos (fix + raise floor, or relax CI lint
  set), widen the CI Flutter matrix.
- 100% coverage drive (separate effort).
