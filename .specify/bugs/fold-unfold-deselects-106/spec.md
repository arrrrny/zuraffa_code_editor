# Spec: fold-unfold-deselects-106

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/106
(upstream `akvelon/flutter-code-editor#189`).

## Requirement

Folding a block and then unfolding it must be a no-op on the selection.

A selection lives in the **visible** text, so while a block is folded the part
of a selection that the block hides can only be shown truncated — clamped to
the fold marker. That is correct. What is not correct is that the truncated
selection then becomes the selection the unfold restores from, so the offsets
the fold removed are lost for good. The selection must come back when the
block that hid it comes back.

The reported claim that a selection "untouched by the fold" is dropped does
not reproduce (see `assessment.md`), and is not what this spec promises.

## Root cause

`CodeController.foldAt` and `unfoldAt` both end in
`super.value = _getValueWithCode(newCode)`, and `_getValueWithCode` lifts the
field's selection into the full text only to immediately project it back:

```dart
selection: newCode.hiddenRanges.cutSelection(
  _code.hiddenRanges.recoverSelection(value.selection),
),
```

The lifted selection is discarded, so nothing remembers what the truncation
removed.

## Acceptance

- A selection the folded block covers is restored by unfolding it.
- A caret inside the folded block is restored by unfolding it.
- A selection straddling the fold boundary is restored by unfolding it.
- A selection the fold does not cover still tracks by the number of hidden
  characters, and unfolds back to the original — unchanged behaviour.
- While a block is folded, a selection it covers shows only its visible
  remainder, clamped to the fold marker (the truncation itself is not undone).
- Moving the selection while the block is folded is not undone by the unfold.
- Unfolding a different block does not resurrect a selection that another
  fold hid.
- A keystroke after a fold/unfold round trip does not resurrect the folded
  selection.
- Fold/unfold round-trips the full text losslessly.
- No regression: full suite green, `dart analyze` clean, `dart format` clean,
  coverage gate at 100%.

## Non-goals

- Refusing a fold whose block covers the selection — the report gives no
  acceptance criteria and refusing a user-requested fold is a bigger change
  than preserving the selection.
- Undoing the truncation while the block is still folded: the hidden text has
  no visible representation to select.
- The fold-state transfer between two textually identical but distinct blocks
  (#108), which shares this file's history but is a different calculation.
