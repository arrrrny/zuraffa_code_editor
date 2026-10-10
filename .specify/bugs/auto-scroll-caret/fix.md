# Fix: Bound the code field to the viewport so typing auto-scrolls

Status: **applied** — branch `bug/auto-scroll-caret`, base master `ff02b3b`.
Source assessment: ./assessment.md (issue #42).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/code_field/code_field.dart` | `_wrapInScrollView` now takes the editor box `maxHeight` and bounds the non-`expands` field with a `ConstrainedBox`; the `LayoutBuilder` forwards `constraints.maxHeight` |
| `test/src/code_field/auto_scroll_caret_test.dart` | **new** — widget test: 40 typed lines in a 200px-tall field must scroll the `Scrollable` inside the `EditableText` |

## Deviations from the assessment

- None. The repro test failed exactly as predicted on master (RenderFlex
  overflow by 792px + `Expected: > 0`) and passes with the fix.

## Verification

- `flutter test test/src/code_field/auto_scroll_caret_test.dart` — green
  (verified red on master via `git stash`, then green).
- `flutter test` — 424 tests, all passing (423 pre-existing + 1 new).
- `dart analyze --fatal-infos` — No issues found.
- `dart format --output=none --set-exit-if-changed lib test` — clean.

## Coverage note

The change only adds widget-tree structure exercised by every existing
`CodeField` widget test; measured coverage does not regress.
