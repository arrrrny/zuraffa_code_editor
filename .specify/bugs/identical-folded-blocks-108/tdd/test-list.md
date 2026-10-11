# Test List: identical-folded-blocks-108

Derived from `.specify/bugs/identical-folded-blocks-108/spec.md`.
Engine: `zfa tdd plan` unavailable (`ZFA_MISSING`, no `.zfa.json`) — this list
was derived by hand following the skill's fallback path.

## Fault-detecting tests (must be RED before the fix)

| # | Test | Detects |
|---|------|---------|
| 1 | `test/src/folding/fold_survives_identical_blocks_test.dart` → `deletes the folded identical block without folding the survivor` | the fold transferring to the surviving identical block |
| 2 | same file → `a folded block survives an edit well away from it` | a too-broad guard unfolding a fold the edit never touched |
| 3 | same file → `a folded block survives an edit on its own first line` | the guard also rejecting edits on the visible line (the branch that keeps caret-on-opener edits folding) |
| 4 | same file → `a folded block does not survive a change of its hidden content` | the guard collapsing to "never survives any nearby edit" |

## Characterisation tests (already GREEN — pin the unchanged paths)

| # | Test | Pins |
|---|------|---------|
| 5 | `test/src/code_field/code_controller_folding_editing_test.dart` → `When deleting 2nd identical folded block, 1st one does not fold` | the existing coverage of the widget path, updated from the recorded bug to the fixed outcome (it is the same scenario through `CodeField`, with `pumpController` and a real key event) |
| 6 | `test/src/folding/*` (existing suite) | every other fold-matching path: comment groups, read-only blocks, folds away from any edit |
| 7 | `test/src/code_field/code_controller_paste_hidden_test.dart` (new branch test) | the non-collapsed-selection paste path, restored to 100% coverage |

## Cycle log

See `cycle-log.md`.
