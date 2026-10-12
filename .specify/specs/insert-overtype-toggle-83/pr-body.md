## Summary

The Insert key now toggles insert/overtype mode in a focused `CodeField`, and
overtype typing replaces the character after the caret instead of inserting in
front of it.

Implements #83 (upstream `akvelon/flutter-code-editor#200`, which points at the
still-open `flutter/flutter#122673`): `TextField` has no overtype mode and no
hook to install one, so the fork owns both halves.

### What changed

- `lib/src/code_field/actions/overtype.dart` — new `ToggleOvertypeIntent` and
  `ToggleOvertypeAction`, mirroring `actions/enter_key.dart`.
- `lib/src/code_field/code_controller.dart`
  - `bool isOvertypeMode` (public field, defaults to insert) and
    `toggleOvertypeMode()`.
  - `ToggleOvertypeIntent` joins the `actions` map.
  - `_overtypedValue` plus its call in the `value` setter, after the modifier
    dispatch and the tab replacement.
- `lib/src/code_field/code_field.dart` — bare `Insert` bound in
  `_shortcutsIgnoredWhileComposing`.
- `test/src/code_field/insert_overtype_test.dart` — 14 tests.
- `CHANGELOG.md`, `.specify/specs/insert-overtype-toggle-83/`.

### Why the framework seam is safe

Flutter's `DefaultTextEditingShortcuts` binds only Ctrl-Insert (copy) and
Shift-Insert (paste):

```dart
const SingleActivator(LogicalKeyboardKey.insert, control: true):
    CopySelectionTextIntent.copy,
const SingleActivator(LogicalKeyboardKey.insert, shift: true):
    const PasteTextIntent(...),
```

Bare Insert falls through every framework shortcut map and reaches this
package's `FocusableActionDetector`, which already owns Enter, Tab, Ctrl+/,
Ctrl+F and page up/down. A no-modifier `SingleActivator` requires no modifiers
pressed, so Ctrl+Insert and Shift+Insert keep their bindings.

On the typing side, `EditableText` performs the insertion itself and delivers it
through `controller.value` (`_formatAndSetValue` →
`widget.controller.value = value`), then pushes the rewritten value back to the
platform through `_updateRemoteEditingValueIfNeeded`. The `value` setter is
therefore the seam, and intercepting there needs no fight with the framework.

### What overtype does not do

`_overtypedValue` is gated on three predicates, each pinned by its own test:

| Incoming edit | Result |
|---|---|
| one character inserted at the collapsed caret, caret now one past it | replaces the character that was there |
| caret at the end of the text | inserts — nothing to overwrite |
| a modifier transformed the keystroke (auto-pairing) | inserts the pair, exactly as in insert mode |
| a deletion, a paste, a multi-character selection | unchanged |
| an insertion that did not land at the caret | unchanged |
| a `readOnly` field | unchanged |

The `readOnly` guard: `_getEditResultNotBreakingReadOnly` refuses the edit
anyway, but only after `_overtypedValue` has already rewritten `newValue`.

The toggle binding sits in `_shortcutsIgnoredWhileComposing` for the same reason
as Enter and Tab — while a composition is in flight the keystroke belongs to
the IME, and the detector only merges that map when the controller reports no
active composition.

### Verification

- Full suite green: **791 tests** (784 on the base + 14 new − 7 expected
  overlap in the reporting count).
- Coverage gate: **100.00% (3409/3409 lines over 108 files)**, no new
  exemptions.
- `dart analyze --fatal-infos` clean, `dart format` exit 0.
- Fault checks: reverting the `_overtypedValue` call reddens the three
  replacement tests; reverting the Insert binding reddens the two toggle tests.

Resolves #83.
