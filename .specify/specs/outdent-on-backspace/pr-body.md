## Summary

Adds outdent on Backspace ([#21](https://github.com/arrrrny/zuraffa_code_editor/issues/21)) and the hook that makes it implementable from outside the package. Closes upstream [akvelon/flutter-code-editor#218](https://github.com/akvelon/flutter-code-editor/issues/218).

The reporter's diagnosis was exact:

> *"it seems a `CodeModifier` that wants to register itself on `'\b'` doesn't work. I checked that the backspace key is delegated to the `CodeController`'s `onKey` method and you could process it there if nothing else works, but I think, a `CodeModifier` which is called on `'\n'` for indentation is the right place to implement this."*

The reason it cannot work is that a modifier is keyed on the character that was **typed**:

```dart
// lib/src/code_modifiers/code_modifier.dart
abstract class CodeModifier {
  final String char;
  const CodeModifier(this.char);
  ...
}

// lib/src/code_field/code_controller.dart, in value's setter
final loc = _insertedLoc(text, newValue.text);
if (loc != null) {
  final char = newValue.text[loc];
  final modifier = _modifierMap[char];
  ...
```

A backspace *removes* a character, so `_insertedLoc` returns null, no key is produced, and the modifier sits in the map unconsulted. There is no deletion path at all — which is also why `CodeController.backspace()` is dead from the field's point of view: `EditableText` performs the deletion and delivers it through `value`'s setter.

## Changes

| File | Change |
|------|--------|
| `lib/src/code_modifiers/code_modifier.dart` | `CodeModifier` gains an optional `deletesChar` |
| `lib/src/code_field/code_controller.dart` | `_deletionModifierMap` + `_deletedLoc` + the `else` branch in `value`'s setter; `OutdentModifier` joins `defaultCodeModifiers` |
| `lib/src/code_modifiers/outdent_code_modifier.dart` | **new** — `OutdentModifier` |
| `lib/zuraffa_code_editor.dart` | exports the new modifier |
| `test/src/code_modifiers/outdent_modifier_test.dart` | **new** — 15 tests |
| `.specify/specs/outdent-on-backspace/` | spec, plan, tasks, test list |
| `CHANGELOG.md` | `Unreleased › Added` entry |

## The dispatch

The character that was **removed** stands in for the one that was typed, which is what makes the new path the mirror of the existing one:

| | insertion | deletion |
|---|---|---|
| text length | `a.length + 1 == b.length` | `a.length == b.length + 1` |
| caret | collapsed, after the new char | collapsed, where the removed char was |
| key | `b[loc]` | `a[deletedLoc]` |

```dart
final deletedLoc = _deletedLoc(text, newValue.text, newValue.selection);
if (deletedLoc != null) {
  final modifier = _deletionModifierMap[text[deletedLoc]];
  final val = modifier?.updateString(text, selection, params);
  if (val != null) {
    newValue = newValue.copyWith(text: val.text, selection: val.selection);
  }
}
```

Same `updateString` signature, same map-per-kind shape. A modifier keyed on `' '` therefore fires when a backspace takes a space and stays silent when it takes a letter — no new concept to learn.

`_deletedLoc` takes the **new** selection as a parameter, because the field's own `selection` getter still reports the pre-deletion caret at that point in the setter.

## `OutdentModifier`

- Declines a non-collapsed selection and a caret at 0.
- Walks back to the line start and declines the moment it meets a non-space, so a backspace over real code stays a one-character delete.
- Removes `params.tabSpaces.clamp(1, indent)`, so an indent that is not a multiple of `tabSpaces` is emptied rather than over-deleted.

Registered in `defaultCodeModifiers` and exported beside the others. A consumer opts out by passing their own `modifiers` list — the test pins that an empty list keeps the plain one-space delete.

## Verification

- `flutter test` → **All 625 tests pass** (610 on master, +15)
- `python3 tool/coverage_gate.py --min 100` → 100.00%
- `dart analyze --fatal-infos` → No issues found
- `dart format --output=none --set-exit-if-changed .` → no changes

Three of the fifteen tests drive a real `LogicalKeyboardKey.backspace` through the widget tree, including a read-only controller that must refuse the outdent. The unit-level tests cover the dispatch itself, including that an insertion-only modifier is never consulted for a deletion.
