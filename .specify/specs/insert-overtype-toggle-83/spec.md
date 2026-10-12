# Feature: Insert toggles insert/overtype mode

**Issue:** [arrrrny/zuraffa_code_editor#83](https://github.com/arrrrny/zuraffa_code_editor/issues/83) — synced from upstream `akvelon/flutter-code-editor#200 — "Insert key doesn't switch between overtype and insert modes"`, which points at the open `flutter/flutter#122673`.
**Label:** `spec`

## Problem

Pressing Insert does nothing in a focused `CodeField`. Upstream's answer is that
this is a Flutter gap: `TextField` has no overtype mode and no hook to install
one.

The framework side is confirmed rather than assumed. `DefaultTextEditingShortcuts`
binds exactly two Insert keys:

```dart
const SingleActivator(LogicalKeyboardKey.insert, control: true):
    CopySelectionTextIntent.copy,
const SingleActivator(LogicalKeyboardKey.insert, shift: true):
    const PasteTextIntent(...),
```

There is no bare `Insert`, so the key falls through every shortcut map the
framework installs and lands on this package's `FocusableActionDetector`. That
detector already owns the editor's own bindings (Enter, Tab, Ctrl-/, Ctrl+F,
page up/down), which is where the toggle belongs.

The typing side is confirmed too: `EditableText` performs the insertion itself
and delivers it through `controller.value` (`_formatAndSetValue` →
`widget.controller.value = value`), then pushes our rewritten value back to the
platform through `_updateRemoteEditingValueIfNeeded`. So replacing that one
character needs no fight with the framework — the `value` setter is the seam.

## Scope

1. `CodeController` gains `isOvertypeMode` (default `false`) and
   `toggleOvertypeMode()`. The host reads and sets the flag directly; the Insert
   key flips it.
2. A `ToggleOvertypeIntent` / `ToggleOvertypeAction` pair mirrors
   `actions/enter_key.dart`, registered in `CodeController.actions` and bound to
   bare `Insert` in `_shortcutsIgnoredWhileComposing`.
3. While overtype is on, a plain one-character keystroke at a collapsed caret
   replaces the character after the caret. Everything else is untouched —
   see "What overtype does not do".

Not in scope: a host-visible caret style, persisting the mode across focus
loss or undo, or an `EditorParams`/`CodeField` constructor argument.

## The toggle surface

`Insert` is bound with a no-modifier `SingleActivator`, which matches only bare
Insert: `_shouldAcceptModifiers` requires `control == controlPressed`, so
`Ctrl+Insert` still resolves to `CopySelectionTextIntent.copy` and `Shift+Insert`
still resolves to the framework's paste. The binding sits in
`_shortcutsIgnoredWhileComposing` for the same reason as Enter and Tab — while a
composition is in flight the keystroke belongs to the IME, and
`FocusableActionDetector` only merges that map when the controller reports no
active composition.

## What overtype does not do

The replacement is scoped to the exact edit a keystroke at the caret produces,
because `_overtypedValue` runs **after** the modifier dispatch:

| Incoming edit | Result |
|---|---|
| one character inserted at the collapsed caret, caret now one past it | replaces the character that was there |
| caret at the end of the text | inserts — there is nothing to overwrite |
| a modifier transformed the keystroke (auto-pairing `()`, smart indent) | inserts the pair, exactly as in insert mode |
| a deletion, a paste, a multi-character selection | unchanged |
| an insertion that did not land at the caret | unchanged |
| `readOnly` controller | unchanged |

The `readOnly` guard is not decoration: `_getEditResultNotBreakingReadOnly`
refuses the edit anyway, but only after `_overtypedValue` has already rewritten
the incoming value.

## Acceptance Criteria

1. Pressing Insert toggles insert/overtype while the field is focused, and
   defaults to insert.
2. Overtype replaces the character after the caret instead of inserting before
   it.
3. The mode is visible to the host (`isOvertypeMode`) and settable.
4. Tests cover the toggle and the replacement, including the paths that must
   stay in insert mode.
5. The 784 existing tests keep passing; no shortcut, modifier or IME path
   changes behaviour.
