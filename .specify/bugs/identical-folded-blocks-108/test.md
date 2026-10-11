# Test: identical-folded-blocks-108

## Full suite

`flutter test` on `bug/identical-folded-blocks-108`:

```
10:32 +781 -1: Some tests failed.
```

**781 tests, 1 failure** — the failure is
`test/src/code_field/no_language_keystroke_test.dart` (the wall-clock keystroke
pin): a median of 123 837 µs against its 100 ms bound, measured while the pool
lanes were running review tasks on the same Mac. It passes when run alone
(`00:23 +3: All tests passed!`) and its path (`highlight.parse` share 0.0%, no
language) is untouched by this fix. Everything else is green (780 passed).

## Coverage

`flutter test --coverage` + `python3 tool/coverage_gate.py --min 100`:

```
zuraffa_code_editor line coverage: 100.00% (3400/3400 lines over 107 files)
```

The fix itself uncovered 6 lines (the non-collapsed-selection paste branch and
`TextEditingValue.replacedText`'s body), closed by the new
selection-ed paste test in `code_controller_paste_hidden_test.dart`.

## New tests

`test/src/folding/fold_survives_identical_blocks_test.dart` (4):

1. `deletes the folded identical block without folding the survivor` — red
   before the fix: `Expected: [] Actual: [FoldableBlock(0-2, braces)]`.
2. `a folded block survives an edit well away from it` — the guard's lower
   bound.
3. `a folded block survives an edit on its own first line` — the visible-line
   exemption.
4. `a folded block does not survive a change of its hidden content` — the
   guard's upper bound.

`test/src/code_field/code_controller_paste_hidden_test.dart` (+1): a paste
delivered with an uncollapsed selection re-anchors to the visible text's
changed range instead of the framework caret.

`test/src/code_field/code_controller_folding_editing_test.dart`: the scenario
that recorded the incorrect fold (its own name, TODO upstream) now asserts no
fold + full text + empty `foldedBlocks`.

## Fault injection

- `_editTouchedHiddenContent()` → always false: reddens test 1 (the fold
  transfers again).
- `_editTouchedHiddenContent()` → always true: reddens tests 2 and 3.
- Plumbing removed (no `changedOldLines` passed): reddens test 1.

## Static checks

`dart analyze --fatal-infos` — no issues. `dart format` — clean.
