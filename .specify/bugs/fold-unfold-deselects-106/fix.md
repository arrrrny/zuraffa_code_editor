# Fix: fold-unfold-deselects-106

- **Status**: applied
- **Branch**: `bug/fold-unfold-deselects-106`
- **Base**: `master` @ `1b8634f` (PR #130 merge)

## What was wrong

`CodeController.foldAt` and `unfoldAt` both end in
`super.value = _getValueWithCode(newCode)`, and `_getValueWithCode` lifted the
field's selection into the full text only to project it straight back through
the new hidden ranges:

```dart
selection: newCode.hiddenRanges.cutSelection(
  _code.hiddenRanges.recoverSelection(value.selection),
),
```

A selection lives in the **visible** text. While a block is folded the part of
a selection that block hides can only be shown truncated, clamped to the fold
marker — correct. But because the lifted selection was discarded, the unfold
had nothing to restore from and recovered the *truncated* selection, so the
offsets the fold removed were lost for good.

The report's claim that a selection "untouched by the fold" is dropped does not
reproduce: a mouse-drag selection over `void method2()` with `void method1()`
folded tracks `[58, 97]` → `[45, 84]` and unfolds back to `[58, 97]`. Only a
selection the folded block covers is affected.

## What changed

`lib/src/code_field/code_controller.dart`:

- New field `TextSelection? _selectionHiddenByFold`.
- `_getValueWithCode` now remembers the lifted selection when the round trip
  through the **new** ranges does not return it — an exact predicate for "the
  fold truncated the selection", since lifting the truncated selection back
  returns the fold marker rather than the original endpoints. When the round
  trip *does* return it, nothing is remembered.
- The `value` setter clears the field: a change from the field re-establishes
  the selection in the visible text, so whatever a fold had truncated is no
  longer what the user is pointing at.
- `applyHistoryRecord` clears it: the record carries a selection of its own.

The result is that a fold behaves exactly as before for every selection it does
not cover, and a fold followed by an unfold is a no-op on the selection.

The one behaviour that is deliberately unchanged: while the block is still
folded, a selection it covers shows only its visible remainder, clamped to the
fold marker. Hidden text has no visible representation to select, and undoing
the truncation there would need a selection the field cannot render.

## Tests

`test/src/code_field/fold_unfold_keeps_selection_test.dart`, new group
`CodeController. Fold and unfold preserve the selection.` (7 tests):

- `a selection inside the folded block survives the round trip` — the
  reported shape: `[43, 58]` → `[42, 45]` while folded → `[43, 58]` again.
- `a caret inside the folded block survives the round trip` — `47` → `42` →
  `47`.
- `a selection straddling the fold survives the round trip` — `[0, 44]` →
  `[0, 42]` → `[0, 44]`.
- `a selection outside the folded block is not resurrected` — the pre-existing
  behaviour, pinned so the fix cannot resurrect a selection the fold never hid.
- `moving the selection after the fold forgets the folded one` — the
  `value`-setter clear.
- `unfolding another block does not resurrect the folded selection` — a fold
  unrelated to the one that hid the selection must not restore it.
- `the remembered selection does not leak into a plain keystroke` — the
  round-tripped selection is the live one, remembered or not.

Fault detection: reverting only the assignment of `_selectionHiddenByFold`
reddens the four behavioural tests (`Expected: <24> Actual: <42>`,
`Expected: <TextSelection(baseOffset: 0, extentOffset: 44, ...)> Actual:
<TextSelection(baseOffset: 0, extentOffset: 42, ...)>`) while the three
regression pins stay green.
