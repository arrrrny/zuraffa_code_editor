# Fix: add GutterStyle.padding (gutter-alignment layer 2)

Status: **applied** — branch `bug/gutter-padding`, base master `ff02b3b`.
Source assessment: ./assessment.md (issue #6).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/line_numbers/gutter_style.dart` | New `padding` field (`EdgeInsets.zero` default), constructor param, carried in `copyWith` |
| `lib/src/gutter/gutter.dart` | `GutterWidget.build` wraps the scroll view in `Padding(padding: style.padding)` inside the existing vertical inset |
| `test/src/gutter/gutter_padding_test.dart` | **new** — 3 tests: defaults, copyWith, and the shift-without-pitch widget test |

## Deviations from the assessment

- None; the remediation landed exactly as proposed (padding outside the
  columns, zero default).

## Verification

- `flutter test test/src/gutter/gutter_padding_test.dart` — green;
  red-checked by reverting the `gutter.dart` hunk (`Expected: <4>
  Actual: <0.0>`).
- `flutter test` — 426 tests, all passing.
- `dart analyze --fatal-infos` — clean; `dart format` — clean.
