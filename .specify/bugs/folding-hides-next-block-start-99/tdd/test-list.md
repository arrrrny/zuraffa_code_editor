# Test list: folding-hides-next-block-start-99

Behaviors derived from `spec.md` acceptance criteria. The project is not
zuraffa-wired (`.zfa.json` absent), so this list was derived by hand per the
LLM-guided fallback in `/speckit-tdd-plan`.

## Outer loop (acceptance)

| ID | Behavior | Criterion | Test |
|----|----------|-----------|------|
| B1 | Folding the two-line touching block keeps the shared line's text on screen | AC-1 | `test/src/folding/folded_block_keeps_next_block_start_test.dart` — "keeps the shared line on screen when the block above it is folded" |
| B2 | The gutter and the editor agree on the row count after that fold | AC-2 | same file — "keeps the gutter and the editor in agreement on the row count" |
| B3 | Fold/unfold round-trips the full text losslessly | AC-3 | same file — "round-trips losslessly" |
| B4 | The leading-closer two-line shape keeps its current glued output | AC-4 | same file — "glues the leading-closer two-line shape as before" |
| B5 | The multi-line #25 shape keeps the closer's own row, number and toggle | AC-5 | existing tests in the same file (already green) |

## Inner loop (unit)

| ID | Behavior | Traces to | Test |
|----|----------|-----------|------|
| U1 | `foldableBlockToHiddenRange` ends at the shared line's start when another block starts there and no content row separates them | B1 | exercised through B1 (range asserted indirectly via `visibleText`); bounds via B4 |

## Status

All behaviors PENDING at baseline (2026-10-11, master `b86cef9`).
