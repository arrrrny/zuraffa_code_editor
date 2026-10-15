# TDD test list — #175 fold survives a newline deletion next to it

Feature dir: `.specify/bugs/fold-hidden-range-lost-on-newline-delete`
Source spec: ./spec.md

## Tests

| # | Test file | Test | Rule | Red reason |
|---|---|---|---|---|
| T1 | `test/src/folding/fold_survives_newline_after_fold_test.dart` (new) | `Deleting the newline right after the closer row` | R1 | `foldedBlocks` becomes empty and the visible text comes back `a {\n  body();\n}…` |
| T2 | same | `Deleting a blank line further away` | R1 | passes on master (guard against over-fixing) |
| T3 | same | `The block is still unfoldable afterwards` | R4 | unfold is a no-op when the fold is already gone |
| T4 | same | `But the hidden content changing still drops the fold` | R1 | passes on master (guard: the fix must not keep folds whose content changed) |
| T5 | `test/src/code_field/code_controller_folding_editing_test.dart` | group `Deleting a newline after a folded block` → `The fold survives and the hidden content stays hidden` | R1, R4 | same defect through a real `CodeField` selection edit |
| T6 | same (existing) | `When deleting 2nd identical folded block, 1st one does not fold` | R2 | passes on master — regression guard for #108, must stay green |
| T7 | `test/src/code/code_line_test.dart` (new) | `isClosingLine` classification for `)`, `]`, `}`, `);`, `},` and content rows | R3, R1 | new getter, no coverage without it |

## Not tested here (already covered)

- The `#START section1` typing case (`code_controller_folding_editing_test.dart`,
  "Manually typed in a text that has become a hidden range").
- The collapsed-Backspace path (#222 guard) — pinned by
  `code_get_edit_result_test.dart`'s "keeps text on backspace into a folded
  block".
