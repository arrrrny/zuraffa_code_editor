# Feature: Outdent on Backspace

**Issue:** [arrrrny/zuraffa_code_editor#21](https://github.com/arrrrny/zuraffa_code_editor/issues/21) — synced from upstream `akvelon/flutter-code-editor#218 — "Outdent on Backspace"`.
**Label:** `spec`

## Problem

The reporter wants a dedent on Backspace and tried to build it the documented
way — as a `CodeModifier` registered on `'\b'` — and found it cannot fire:

> *"it seems a `CodeModifier` that wants to register itself on `'\b'` doesn't
> work. I checked that the backspace key is delegated to the `CodeController`'s
> `onKey` method and you could process it there if nothing else works, but I
> think, a `CodeModifier` which is called on `'\n'` for indentation is the right
> place to implement this."*

The diagnosis is exact. `CodeModifier` is keyed on a character:

```dart
abstract class CodeModifier {
  final String char;
  const CodeModifier(this.char);
  ...
}
```

and `CodeController` dispatches from `value`'s setter, where the key is the
character that was **typed**:

```dart
if (hasTextChanged) {
  final loc = _insertedLoc(text, newValue.text);
  if (loc != null) {
    final char = newValue.text[loc];
    final modifier = _modifierMap[char];
    final val = modifier?.updateString(text, selection, params);
    ...
```

`_insertedLoc` returns the caret offset only when exactly one character was
inserted. A backspace removes a character, so it returns null, no key is
produced, and no modifier — registered on anything — is consulted. There is no
deletion path at all.

Consequences:

- Nobody can implement dedent-on-backspace from outside the package, which is
  what the issue is about.
- The editor's own `CodeController.backspace()` exists but is dead code from the
  field's point of view: the framework's `EditableText` performs the deletion and
  delivers it through `value`'s setter, so the key-event path never runs it.

## Scope

Open the extension point the reporter asked for, then exercise it with the
modifier they wanted.

1. `CodeModifier` gains an optional `deletesChar` naming the character whose
   **deletion** it reacts to; `CodeController` keeps a second map for those and
   dispatches a single-character backspace deletion through it. Insertion
   dispatch is untouched.
2. A new `OutdentModifier` is shipped and added to `defaultCodeModifiers`. When
   the caret sits in a line's leading whitespace, Backspace removes one indent
   level (`params.tabSpaces`) instead of one space; anywhere else it returns
   null and the ordinary one-space delete stands.
3. Read-only and folded-range rules keep applying — the modifier transforms the
   value before `_getEditResultNotBreakingReadOnly`, not after.

Not in scope: forward-delete, multi-character selections, or changing how
`onKey` dispatches anything.

## Why a modifier and not an `onKey` branch

The reporter's instinct is right and the codebase agrees: every other
character-driven behaviour (`IndentModifier` on `'\n'`, the paired-symbol
`InsertionCodeModifier`s) lives in a modifier, so they are testable without a
widget tree, they see the real text and selection, and a consumer can add their
own. `onKey` gets the raw `KeyEvent` before the framework has applied it, which
means its implementation would have to re-derive the deletion the text field is
about to perform — the reason the reporter found the key path dead.

## Acceptance Criteria

1. A modifier registered with `deletesChar: '\b'` is consulted when the user
   backspaces a character, with the text and selection it would have seen on an
   insertion.
2. A modifier registered only on an inserted character is **not** consulted on a
   deletion, so existing insertion modifiers keep their exact behaviour.
3. `OutdentModifier` removes one indent level from a caret inside the leading
   whitespace of an indented line.
4. `OutdentModifier` does not fire when the caret is not in the leading
   whitespace — Backspace deletes one character as it does today.
5. `OutdentModifier` does not fire past the start of the leading whitespace:
   outdenting a line indented by 2 with `tabSpaces` 4 removes those 2 spaces.
6. Deleting a selection, or deleting at the caret with no character before it, is
   unchanged.
7. `OutdentModifier`'s effect survives the read-only and folded-range paths: a
   read-only line and a caret inside a folded block still refuse the edit.
8. The 610 existing tests keep passing; no insertion modifier changes behaviour.
