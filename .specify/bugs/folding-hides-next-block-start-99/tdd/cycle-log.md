# Cycle log: folding-hides-next-block-start-99

Project is not zuraffa-wired (`.zfa.json` absent) — LLM-guided loop per the
`/speckit-tdd-run` fallback. Baseline: master `b86cef9`, branch
`bug/folding-hides-next-block-start-99`.

## Red

Instrumentation probe on unmodified master (probe deleted afterwards):

```
--- two-line
blocks: [0..6, 2..3, 3..5]
range for 2: [38, 49)
hiddenRanges: [[38,49) 2..3 whole=false]
breakpoints: [LineNumberingBreakpoint: 4 -> 3 (spreadBefore = 0)]
visibleLineNumbers: [0, 1, 2, 4, 5, 6, 7]
visibleText:
void f() {
  int value = 1;
  if (a &&
    g();
  }
}
```

The shared line `      b) {` (line 3) is inside the hidden range: its text is
gone from the editor and it maps to no visible row. `joinIntersecting` already
keeps the blocks separate (`[0..6, 2..3, 3..5]`) — only the hidden-range end is
wrong. For comparison, the leading-closer shape:

```
--- two-line-brace
blocks: [0..1, 1..3]
range for 0: [21, 22)
breakpoints: [LineNumberingBreakpoint: 2 -> 1 (spreadBefore = 0)]
visibleText:
int factorial(int n){}void main(){
```

…glues the shared line onto the opener row and keeps its text. The two shapes
fold inconsistently; the fix makes the non-leading-closer shape do the same.

Regression tests B1–B4 added to
`test/src/folding/folded_block_keeps_next_block_start_test.dart` —
**all four RED** on the unfixed tree (next entry).

## Green — fix applied (master `895f7e2`)

`foldableBlockToHiddenRange` gained an `else if (closerOnItsOwnRow ==
startOfRange)` branch to the `_startsAnotherFoldableBlock` guard, ending the
range at the shared line's start so the line is glued onto the opener's row
instead of hidden whole. The stale "known limitation" comment that described
this sub-shape as unfixed was removed.

- B1 `keeps the shared line on screen when the block above it is folded` — RED
  (`if (a &&` directly followed by `g();`) → **GREEN**.
- B2 `keeps the gutter and the editor in agreement on the row count` — GREEN.
- B3 `round-trips losslessly` — GREEN.
- B4 `glues the leading-closer two-line shape as before` — GREEN (pins that the
  pre-existing leading-closer fold is unchanged).
- `is a foldable block of its own` — GREEN (pins blocks `['2..3', '3..5']`).
- Existing groups (multi-line `}void main(){`, non-leading multi-line closer,
  gutter fold-toggle widget test) — all still GREEN, 69 folding tests in total.

Full suite 720 passed · `dart analyze --fatal-infos` clean ·
`dart format` 0 changed · coverage gate 100.00% (3347/3347).

Artifacts: `fix.md`, `test.md`.
