# Bug Test Report: IME composition duplicates/drops characters

- **Slug**: ime-composition-duplicates-characters
- **Issue**: 11
- **Result**: pass

## TDD cycle

1. RED — `test/src/code_field/code_controller_ime_composition_test.dart` and
   the new clamping test in `test/src/code/code_get_edit_result_test.dart`
   written first. Observed failures (excerpt):
   - `Composing-only updates are applied` — composing stayed `(0,1)` instead
     of `(0,2)`.
   - `Composing text is committed correctly after IME selection` — actual
     text `'} n'` (the candidate was deleted; the core defect).
   - `Modifiers do not fire while composing` — actual `'a()'`.
   - `A transient out-of-range selection ...` — `RangeError: Invalid value:
     Not in inclusive range 0..3: 5` from `tabsToSpaces` → `beforeSelection`.
   - `Enter and Tab actions are ignored during composition` — actual
     `'ni\n'`.
   - `onKey ignores the autocomplete popup during composition` — arrow key
     reached `popupController.scrollByArrow`.
   - `buildTextSpan is composing-aware while composing` — custom highlighted
     span returned while composing.
   - clamp test — `RangeError: Invalid value: Not in inclusive range 0..3: 10`.
2. GREEN — the fix made all tests pass (314 total, no regressions).
3. Mutation — see tdd/verification.md.

## Coverage of the fix

Every new branch in the controller, the widget shortcut map and
`Code.getEditResult` is exercised by at least one test. Measured line
coverage on this branch: 90.66% (2690/2967), unchanged from master — the fix
adds no uncovered lines.

## Caveat (honest)

- The Windows engine-level duplication itself is not reproducible in a VM
  test; the pinned invariant is that composing-only platform updates are
  stored and the commit is not transformed.
- The Enter shortcut has two gates (controller action + widget shortcut map);
  the widget-level gate alone is only observable when both are mutated, which
  verification.md records.
