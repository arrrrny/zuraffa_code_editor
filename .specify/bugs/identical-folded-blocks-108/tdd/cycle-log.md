# Cycle Log: identical-folded-blocks-108

Engine: `zfa tdd run` unavailable (`ZFA_MISSING`, no `.zfa.json`) — the
red-green-refactor loop was driven by hand following the skill's fallback path.

## RED

Wrote `test/src/folding/fold_survives_identical_blocks_test.dart` (4 tests)
before touching `lib/`.

The first red was behavioural:

```
Expected: [FoldableBlock(0-2, FoldableBlockType.braces)]
  Actual: [FoldableBlock(0-2, FoldableBlockType.braces)]
```

— the fold had transferred to the surviving identical block, i.e. the test
that must see an empty `foldedBlocks` set saw the transferred fold. (The
fold-away-from-edit and edit-on-first-line tests stayed green, which pinned the
boundaries the fix was not allowed to move.)

The three sibling tests pinned the false-pass directions in the same round:
a guard that unfolded everything near an edit reddens #2, and a guard that
accepted any nearby edit reddens #4.

The pre-existing `code_controller_folding_editing_test.dart` scenario
("When deleting 2nd identical folded block, 1st one incorrectly folds",
itself a TODO upstream) flipped from passing to failing with the same
expected/actual mismatch — the recorded bug, now red.

## GREEN

Threaded the edit's changed old-line range through:

- `FoldableBlockMatcher` gained an optional `TextRange? changedOldLines` and a
  `_editTouchedHiddenContent()` helper: the fold's first hidden line must not
  overlap the changed old-line range; the block's own first line is exempt so
  an edit on the visible line keeps the fold.
- `Code.foldedAs(oldCode, {TextRange? changedOldLines})` passes it down.
- `CodeController._updateCodeIfChanged` / `_updateCode` accept the same
  parameter and pass `editResult.linesChanged`.

All 4 new tests went green together with the flipped pre-existing test; the
rest of the 781-test suite stayed green.

## COVERAGE

The fix uncovered the non-collapsed-selection branch of the paste handler
(`code_controller.dart` `newValue.replacedText(_code.visibleText)` — 2 lines)
plus `replacedText`'s body (4 lines), because the one existing paste test
delivers a collapsed caret. Added a selection-ed paste test to
`test/src/code_field/code_controller_paste_hidden_test.dart` that re-anchors
the selection to the changed range instead of the framework caret. Gate back
to 100.00% (3400/3400 lines over 107 files).

## Fault injection

- Reverting `_editTouchedHiddenContent()` to always return false reddens the
  deletion test (#1) with the transferred fold.
- Reverting it to always return true reddens the survives-away (#2) and
  survives-first-line-edit (#3) tests.
- Reverting the `changedOldLines` plumbing (passing null) reddens #1.
