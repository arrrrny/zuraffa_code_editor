# Fix: autocomplete popup is never transparent

Status: **applied** — branch `bug/autocomplete-popup-transparency`, base master `0d57280`.
Source assessment: ./assessment.md (issue #34).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/code_field/code_field.dart` | new `autocompleteBackground` knob; `_popupBackground` resolved once per build as `autocompleteBackground ?? _backgroundCol ?? themeData.cardColor`; `_buildSuggestionOverlay` passes it to `Popup` instead of the null-able `_backgroundCol` |
| `test/src/code_field/autocomplete_popup_background_test.dart` | **new** — 3 widget tests: opaque fallback with a decoration, explicit knob precedence, no-decoration regression |

## Deviations from the assessment

- The knob is named `autocompleteBackground` (the assessment left the name
  open) — parallel to `background`/`decoration` but names which surface it
  styles.
- The fallback is `themeData.cardColor`, not `DefaultStyles.backgroundColor`:
  the latter is `grey.shade900`, which would drop a dark popup on a light
  theme and reintroduce the reporter's complaint in the other direction.
  The `?? scaffoldBackgroundColor` tail the assessment suggested was dropped
  because `cardColor` is non-nullable and the analyzer flagged it as dead
  code.

## Verification

- `flutter test test/src/code_field/autocomplete_popup_background_test.dart`
  — 3/3 green (verified red on master: `Expected: not null`, `Actual: <null>`).
- `flutter test` — 495 tests, all passing.
- `dart analyze --fatal-infos` — No issues found.
- `dart format lib test` — clean (0 changed).

## Coverage note

`lib/src/wip/autocomplete/popup.dart` is not exempt from the ratchet. The
popup is now built with a non-null background by every test that opens it,
and the decoration path is exercised; the gap this closes is the same one
the assessment flagged as being touched by this fix. Coverage is measured in
CI before the gate ratchet is decided.
