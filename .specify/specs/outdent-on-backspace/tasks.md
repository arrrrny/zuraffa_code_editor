# Tasks: Outdent on Backspace

**Spec:** ./spec.md · **Plan:** ./plan.md · **Test list:** ./test-list.md

## Phase 1 — the deletion dispatch (behaviour)

- [x] T1 [behaviour] `CodeModifier` gains the optional `deletesChar` field, with a doc comment explaining why a deletion cannot be keyed on the typed stream.
- [x] T2 [behaviour] `CodeController` gains `_deletionModifierMap`, populated in the constructor beside `_modifierMap`.
- [x] T3 [behaviour] `CodeController._deletedLoc` mirrors `_insertedLoc` for a single-character collapsed deletion.
- [x] T4 [behaviour] `value`'s setter consults the deletion map in the `else` of the insertion branch and folds the modifier's value into `newValue`.

## Phase 2 — OutdentModifier (behaviour)

- [x] T5 [behaviour] `lib/src/code_modifiers/outdent_code_modifier.dart`: `OutdentModifier` registered for `' '` deletion, declining non-collapsed selections, caret 0, and any line whose leading run is not all spaces.
- [x] T6 [behaviour] Clamps the removal to the indent that is actually there.
- [x] T7 `defaultCodeModifiers` gains `OutdentModifier()`.
- [x] T8 `zuraffa_code_editor.dart` exports `src/code_modifiers/outdent_code_modifier.dart`.

## Phase 3 — tests

- [x] T9 `test/src/code_modifiers/outdent_modifier_test.dart`: tests 1–5 pin the dispatch (including that insertion-only modifiers are never consulted).
- [x] T10 Tests 6–12 pin `OutdentModifier` across the indent shapes, `tabSpaces`, the no-op cases and the opt-out.
- [x] T11 Tests 13–15 drive a real `LogicalKeyboardKey.backspace` through `createApp`, one of them read-only.

## Phase 4 — records

- [x] T12 `CHANGELOG.md` entry under `Unreleased › Added`.
- [ ] T13 Push the branch and open the PR labelled `spec`.

## Done

- [x] Full suite green (625 = 610 on master + 15).
- [x] Coverage gate 100.00%, `dart analyze --fatal-infos` clean, format gate
      exit 0.
