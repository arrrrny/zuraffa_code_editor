# Fix: Guarded popup-offset scroll reads (scroll-controller-not-attached)

Status: **applied** — branch `fix/scroll-controller-not-attached`, base master `a7c52bf`.
Source assessment: ./assessment.md (issue #10, upstream akvelon/flutter-code-editor#275).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/code_field/code_field.dart` | New `@visibleForTesting double scrollOffsetOrZero(ScrollController)` returning `0` when `!hasClients`; `_getPopupLeftOffset()` and `_getPopupTopOffset()` read both scroll controllers through it |
| `test/src/code_field/popup_offset_detached_scroll_test.dart` | **new** — 2 unit tests (detached / attached controller) + 2 widget tests (analysis notification with detached controllers, laid-out field) |

## Deviations from the assessment

- The crash could not be reproduced as a widget test on Flutter 3.47.5 (see
  assessment.md → "Reproducibility"): the test binding builds and lays out in
  the same synchronous frame, so the "mounted but not laid out" window the
  reporter hit is unreachable from a test. The fix is therefore pinned by a
  unit test on the extracted helper, which was mutation-checked: removing the
  `hasClients` guard reproduces the upstream assertion
  (`ScrollController not attached to any scroll views`) as a test failure.
- The helper is `@visibleForTesting` and public (the library exports
  `src/code_field/code_field.dart`), so it appears in the package's public
  surface. This is the only way to make the guard mutation-detectable; the
  alternative — testing a private method — is impossible.

## Verification

- `flutter test test/src/code_field/popup_offset_detached_scroll_test.dart`
  → 4 tests, all green.
- Mutation: guard removed → B1 fails with the upstream assertion, guard
  restored.
- `flutter test` → **299 tests, all green** (295 pre-existing on master + 4 new).
- `dart analyze --fatal-infos` → 24 info-level issues, identical to the
  pre-existing master set; no new findings (the `meta` import the first pass
  added was removed as redundant).
- `dart format --output=none --set-exit-if-changed` on the two touched files →
  clean. (The two pre-existing drifts on master —
  `lib/src/code/code.dart`, `test/src/folding/folded_closing_line_test.dart` —
  are untouched here.)

Verified locally on Flutter 3.47.5 / Dart 3.13.4.
