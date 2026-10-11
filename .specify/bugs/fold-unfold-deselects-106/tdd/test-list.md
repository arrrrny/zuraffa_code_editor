# Test list: fold-unfold-deselects-106

Behaviors derived from `spec.md` acceptance criteria. The project is not
zuraffa-wired (`.zfa.json` absent), so this list was derived by hand per the
LLM-guided fallback in `/speckit-tdd-plan`.

## Outer loop (acceptance)

| ID | Behavior | Criterion | Test |
|----|----------|-----------|------|
| B1 | A selection the folded block covers is restored by unfolding it | AC-1 | `test/src/code_field/fold_unfold_keeps_selection_test.dart` — "a selection inside the folded block survives the round trip" |
| B2 | A caret inside the folded block is restored by unfolding it | AC-2 | same file — "a caret inside the folded block survives the round trip" |
| B3 | A selection straddling the fold boundary is restored by unfolding it | AC-3 | same file — "a selection straddling the fold survives the round trip" |
| B4 | A selection the fold does not cover still tracks and restores exactly | AC-4 | same file — "a selection outside the folded block is not resurrected" |
| B5 | Moving the selection while folded is not undone by the unfold | AC-5 | same file — "moving the selection after the fold forgets the folded one" |
| B6 | Unfolding another block does not resurrect a hidden selection | AC-6 | same file — "unfolding another block does not resurrect the folded selection" |
| B7 | A keystroke after the round trip does not resurrect it | AC-7 | same file — "the remembered selection does not leak into a plain keystroke" |
| B8 | While folded, a covered selection shows only its visible remainder | AC-5 | asserted inside B1 and B3 (`TextSelection(42, 45)` / `end == 42`) |

## Inner loop (unit)

| ID | Behavior | Traces to | Test |
|----|----------|-----------|------|
| U1 | The lifted selection is remembered only when the round trip through the new ranges does not return it | B1 | exercised through B1 (red) and B4 (green — the predicate is false) |
| U2 | The `value` setter drops the remembered selection | B5, B7 | exercised through B5 and B7 |
| U3 | `applyHistoryRecord` drops the remembered selection | B7 | exercised through B7 |

## Status

All behaviors GREEN on `bug/fold-unfold-deselects-106` (2026-10-11, base
`fdfa994`). Fault detection checked by reverting only the assignment of
`_selectionHiddenByFold`: B1, B2, B3 and B7 go red (`Expected: <24> Actual:
<42>` / `Expected: <TextSelection(baseOffset: 0, extentOffset: 44, ...)> Actual:
<TextSelection(baseOffset: 0, extentOffset: 42, ...)>`), while B4, B5 and B6
stay green — the pins are fault-detecting.
