# TDD Cycle Log: IME composition duplicates/drops characters

- **Slug**: ime-composition-duplicates-characters
- **Issue**: 11

## RED

`test/src/code_field/code_controller_ime_composition_test.dart` (9 tests) and
the clamping test in `test/src/code/code_get_edit_result_test.dart` were
written before any lib change. 8 of 10 failed; the two that passed are the
regression pins (commit path correctness, read-only rule).

## GREEN

Ported the upstream-validated shape of the fix (akvelon/flutter-code-editor#319)
without its debug `print` and cosmetic field-type churn: `hasActiveComposition`,
the composing-aware `set value` early path, the action shortcuts, the
composing-aware `buildTextSpan`, the widget shortcut map split, and the
`getEditResult` selection clamping. All 314 tests pass.

## Mutation checks

- Removing the controller `onEnterKeyAction` guard → `Enter and Tab actions
  are ignored during composition` fails.
- Removing the widget composing gate only → no test fails (the controller
  guard still blocks Enter); removing both gates together → `Enter does not
  reach the editor while composing` fails. The pair is pinned as a unit.
- The RED phase already pinpoints the `set value` composing path, the
  selection clamping and `buildTextSpan` (each fails when the corresponding
  fix is absent).

## Full suite

`flutter test` → 314 tests pass (`flutter analyze` → 0 issues,
`dart format` → clean).
