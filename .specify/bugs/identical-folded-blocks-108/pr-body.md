# PR body: identical-folded-blocks-108

# Fix: a deleted folded block no longer folds its surviving identical twin (#108)

Closes #108 (upstream `akvelon/flutter-code-editor#83`).

## What was wrong

Fold one of two textually identical blocks, delete the folded one, and the
survivor folds — though the user never folded it. The gutter flips, a fold
range appears, and pressing the toggle unfolds a block that was never folded.

## Root cause

`FoldableBlockMatcher` re-matches the folds after every edit, and its
`_addIfMatch` decides a fold survived by comparing the fold's **hidden content
lines** with the new block's content. Two textually identical blocks have
identical hidden content, so when the folded block is deleted the matcher finds
the survivor by its content and re-attaches the fold to it. The folded block's
own first (visible) line is exempt from that comparison, so it cannot
disambiguate the two blocks.

## The fix

The edit's changed old-line range now travels with it:

- `FoldableBlockMatcher` takes an optional `TextRange? changedOldLines` and
  drops a fold whose first hidden line (`firstLine + 1`) overlaps that range —
  the content the fold hid is what changed, so the fold belongs to the block
  that was edited away. The block's own first line stays exempt, so an edit on
  the visible line (the common caret-on-opener case) keeps the fold exactly as
  before.
- `Code.foldedAs` and `CodeController._updateCodeIfChanged` / `_updateCode`
  take and pass the parameter (from `editResult.linesChanged`); it is optional
  everywhere, so every path that folds nothing — and the undo/redo history
  path — is unchanged.

## Tests

`test/src/folding/fold_survives_identical_blocks_test.dart` (4 tests):

- **deletes the folded identical block without folding the survivor** —
  the reported defect; red before the fix (`Expected: [] Actual:
  [FoldableBlock(0-2, braces)]`).
- **a folded block survives an edit well away from it** — guards the other
  direction: a fix that unfolded everything near an edit.
- **a folded block survives an edit on its own first line** — the boundary the
  visible-line exemption protects.
- **a folded block does not survive a change of its hidden content** — the
  guard must not collapse into "never survives".

`test/src/code_field/code_controller_folding_editing_test.dart`: the scenario
that recorded the incorrect fold (its own name, with a TODO pointing here) is
flipped to the fixed outcome — full text in the value, empty `foldedBlocks`.

`test/src/code_field/code_controller_paste_hidden_test.dart`: a new
selection-ed paste test re-anchors the selection to the visible text's changed
range. The fix uncovered that branch (the caret pasted into hidden text), so
this is the coverage pin that keeps the gate at 100%.

Coverage gate: **100.00% (3400/3400 lines over 107 files)**. Fault injection
(guard always false / always true / no plumbing) reddens the tests above.
