# Plan: Outdent on Backspace

**Spec:** ./spec.md
**Issue:** [arrrrny/zuraffa_code_editor#21](https://github.com/arrrrny/zuraffa_code_editor/issues/21)
**Label:** `spec`

## Design

The dispatch lives in one place and gets a sibling table.

### 1. `CodeModifier` gains `deletesChar`

```dart
abstract class CodeModifier {
  /// The character whose insertion this modifier reacts to.
  final String char;

  /// The character whose deletion this modifier reacts to, or null when this is
  /// an insertion-only modifier.
  final String? deletesChar;

  const CodeModifier(this.char, {this.deletesChar});
```

Deletions insert no character, so there is nothing in the typed stream to key the
dispatch on. The character **removed** stands in for it, which mirrors the
insertion path exactly: the same `updateString` signature, the same map-per-kind
shape, and a modifier that keys on `' '` fires when a backspace removes a space
and stays silent when it removes a letter.

### 2. `CodeController` keeps a second map and a mirrored locator

```dart
final _deletionModifierMap = <String, CodeModifier>{};
```

populated in the constructor beside the existing insertion map, and a
`_deletedLoc` that is the mirror of `_insertedLoc`:

| | insertion | deletion |
|---|---|---|
| text length | `a.length + 1 == b.length` | `a.length == b.length + 1` |
| caret | collapsed, after the new char | collapsed, where the removed char was |
| key | `b[loc]` | `a[deletedLoc]` |

`_deletedLoc` takes the **new** selection as a parameter, because the field's own
`selection` getter still reports the pre-deletion caret at that point in the
setter.

### 3. `OutdentModifier`

Reachable only through the deletion map (`super(' ', deletesChar: ' ')`), it:

1. declines a non-collapsed selection or a caret at 0 — nothing to outdent;
2. walks back to the line start, and declines the moment it meets a non-space:
   a backspace over real code is not an outdent;
3. removes `params.tabSpaces.clamp(1, indent)`, so an indent that is not a
   multiple of `tabSpaces` is emptied rather than over-deleted.

Added to `defaultCodeModifiers`, and exported from
`zuraffa_code_editor.dart` beside the other modifiers so a consumer can opt out
by supplying their own `modifiers` list.

## Order of work

1. `deletesChar` + `_deletionModifierMap` + `_deletedLoc` and the `else` branch
   in `value`'s setter. Tests 1–5.
2. `OutdentModifier`, registered by default and exported. Tests 6–12.
3. Real-key and read-only coverage. Tests 13–15.
4. CHANGELOG entry.

## Risks

- **The dispatch runs on the hottest path in the package.** It is guarded by
  `_deletedLoc`, which rejects anything that is not a single-character collapsed
  deletion, and it only consults a map that is empty unless the consumer
  registered a deletion modifier. With no such modifier the added cost is one
  length comparison.
- **Read-only and folded ranges** must keep refusing edits. The modifier result is
  folded into `newValue` *before* `_getEditResultNotBreakingReadOnly`, so those
  guards still run on the transformed value — the read-only test pins this.
- **`IndentModifier` and the paired-symbol modifiers** are insertion-only and are
  untouched: they keep their `_modifierMap` entry and never see a deletion.
