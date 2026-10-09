# Bug Fix Log: IME composition duplicates/drops characters

- **Slug**: ime-composition-duplicates-characters
- **Issue**: 11

## Changed

- `lib/src/code_field/code_controller.dart`
  - Added `hasActiveComposition`.
  - `set value` now tracks `hasComposingChanged` and applies composing-only
    updates; while a composition is active in the old or new value it stores
    the platform value verbatim after `_updateCodeIfChanged(newValue.text)`,
    skipping modifiers, `tabsToSpaces`, diffing and hidden-range recovery.
  - `onKey`, `onEnterKeyAction`, `onTabKeyAction` are ignored while composing.
  - `buildTextSpan` delegates to `super.buildTextSpan` while composing.
- `lib/src/code_field/code_field.dart`
  - Enter/Tab/Escape shortcuts moved into
    `_shortcutsIgnoredWhileComposing`, merged into the map only when no
    composition is active.
- `lib/src/code/code.dart`
  - `getEditResult` clamps `oldSelection` and `visibleAfter.selection` into
    the respective text ranges before diffing and materializing the edit.
- `test/src/code_field/code_controller_ime_composition_test.dart` (new)
  - 9 tests: composing-only update, commit after IME selection, modifier
    bypass, transient out-of-range selection, read-only rule, Enter/Tab guard,
    popup arrow-key guard, composing-aware `buildTextSpan`, Enter shortcut.
- `test/src/code/code_get_edit_result_test.dart`
  - New test pinning the selection clamping in `getEditResult`.

## Not changed

- The diff-based Latin-input path in `set value` (modifiers, history,
  hidden-range recovery) is untouched and fully covered by the existing suite.

## Verification limits

The engine-side duplication on Windows (IME state desync) cannot be exercised
in a VM widget test; the controller invariant that removes it — composing-only
updates reach the engine — is pinned by test 1. Windows/web verification
would require running the example app on those platforms.
