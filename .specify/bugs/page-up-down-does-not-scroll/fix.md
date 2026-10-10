# Fix: Page Up / Page Down scroll the editor by one viewport

Status: **applied** — branch `bug/page-scroll`, stacked on
`bug/auto-scroll-caret` (PR #51), base master `ff02b3b`.
Source assessment: ./assessment.md (issue #27).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/code_field/actions/page_scroll.dart` | **new** — `PageScrollIntent(forward:)` + `PageScrollAction` animating the field's own scroll controller by one editor-box height (clamped) |
| `lib/src/code_field/code_field.dart` | PageUp/Down shortcut bindings; the state composes the action into the detector's action map (it needs `_codeScroll`, a view concern) |
| `test/src/code_field/page_scroll_test.dart` | **new** — page down/up widget test |

## Deviations from the assessment

- None.

## Verification

- `flutter test test/src/code_field/page_scroll_test.dart` — green;
  red-checked by reverting only `code_field.dart` (`Expected: 200,
  Actual: 96` — the app-level intent scrolling the wrong scrollable).
- `flutter test` — 425 tests, all passing.
- `dart analyze --fatal-infos` — clean; `dart format` — clean.

## Stacking note

Meaningful only with #42 merged: before the field was bounded to its
viewport it had no internal scroll extent to move. Retarget this PR to
master once PR #51 lands.
