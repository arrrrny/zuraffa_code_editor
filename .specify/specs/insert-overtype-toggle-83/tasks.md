# Tasks: Insert toggles insert/overtype mode

**Spec:** ./spec.md · **Plan:** ./plan.md · **Test list:** ./test-list.md

## Phase 1 — the test file (red)

- [x] T1 `test/src/code_field/insert_overtype_test.dart`: the 14 tests. Red on
      the old base because `CodeController.isOvertypeMode` does not exist.

## Phase 2 — the toggle (behaviour)

- [x] T2 `lib/src/code_field/actions/overtype.dart`: `ToggleOvertypeIntent` +
      `ToggleOvertypeAction`, mirroring `actions/enter_key.dart`.
- [x] T3 `CodeController.isOvertypeMode` (public field) and
      `toggleOvertypeMode()`.
- [x] T4 `CodeController.actions` gains `ToggleOvertypeIntent`.
- [x] T5 `code_field.dart` binds bare `Insert` in
      `_shortcutsIgnoredWhileComposing`.

## Phase 3 — the replacement (behaviour)

- [x] T6 `CodeController._overtypedValue` plus the call in `value`'s setter,
      after the modifier dispatch and the tab replacement.

## Phase 4 — records

- [x] T7 `CHANGELOG.md` entry.
- [ ] T8 Push the branch and open the PR labelled `spec`.

## Done

- [ ] Full suite green (`flutter test`).
- [ ] Coverage gate 100.00%, `dart analyze --fatal-infos` clean, format gate
      exit 0.
