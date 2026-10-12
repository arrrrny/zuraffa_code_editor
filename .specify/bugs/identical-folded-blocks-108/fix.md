# Fix: identical-folded-blocks-108

## Root cause

`FoldableBlockMatcher._addIfMatch` decides a fold survived an edit by comparing
the fold's **hidden content lines** with the new block's content
(`lib/src/folding/foldable_block_matcher.dart`). Two textually identical blocks
have identical hidden content, so deleting the folded block re-attaches the
fold to the surviving block by its content — the fold transfers, exactly as
issue #108 reports. The fold's own first line is exempt from the comparison (it
stays visible), so it cannot disambiguate identical blocks.

## Changes

| file | change |
|---|---|
| `lib/src/folding/foldable_block_matcher.dart` | optional `TextRange? changedOldLines`; new `_editTouchedHiddenContent()` guard: the fold dies when the edit's old-line range overlaps its first hidden line |
| `lib/src/code/code.dart` | `foldedAs(oldCode, {TextRange? changedOldLines})` passes the range down |
| `lib/src/code_field/code_controller.dart` | `_updateCodeIfChanged` / `_updateCode` take the parameter and pass `editResult.linesChanged` |
| `test/src/folding/fold_survives_identical_blocks_test.dart` | new — 4 tests |
| `test/src/code_field/code_controller_folding_editing_test.dart` | the recorded-incorrect test flipped to the fixed outcome (`1st one does not fold`), value + `foldedBlocks` asserted |
| `test/src/code_field/code_controller_paste_hidden_test.dart` | new branch test — selection-ed paste re-anchors to the visible text (restores the 100% gate) |
| `.specify/bugs/identical-folded-blocks-108/*` | the full bug chain + `feature.json` pointer |
| `CHANGELOG.md` | Fixed entry |

The parameter is optional on every level, so every path that folds nothing and
the undo/redo history path call `foldedAs` unchanged.
