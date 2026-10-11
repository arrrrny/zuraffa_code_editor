# Fix: folding-hides-next-block-start-99

- **Status**: applied
- **Branch**: `bug/folding-hides-next-block-start-99`
- **Base**: `master` @ `895f7e2` (PR #122 merge)

## What was wrong

`Code.foldableBlockToHiddenRange` picks the hidden-range end from two rules, and
neither covered a two-line touching block:

1. `_isClosingLine(lastLine)` is true only when the line *starts* with `)`, `]`
   or `}`. The shared line `      b) {` ends with its closer but does not start
   with one, so the heuristic failed and the range ran through the whole line.
2. The `_startsAnotherFoldableBlock` guard ends the range one character before
   the shared line so it keeps a row of its own — but only when a content line
   sits between the opener and the closer (`closerOnItsOwnRow > startOfRange`).
   A two-line block has none (`closerOnItsOwnRow == startOfRange`), so the
   guard was inert and the shared line was hidden whole.

The multi-line shape of the same upstream report (`}void main(){`) was already
fixed by issue #25 / PR #56; the code carried a comment naming this two-line
sub-shape as a known limitation that "wants its own fix".

## What changed

`lib/src/code/code.dart`, `foldableBlockToHiddenRange`: added an
`else if (closerOnItsOwnRow == startOfRange)` branch to the existing
`_startsAnotherFoldableBlock` guard that ends the range at the shared line's
start, hiding only the newline that ended the opener. The shared line is glued
onto the opener's row — the shape `_isClosingLine` already produces for a
leading closer, and the most a two-line fold can offer since `HiddenRange`
asserts `end > start`.

The equality is what keeps the change narrow:

- a block whose last line is a later line has `closerOnItsOwnRow > startOfRange`
  and keeps its own closer row (unchanged);
- the degenerate single-line block has `closerOnItsOwnRow` *before*
  `startOfRange`, so it reaches neither branch (unchanged).

The stale "known limitation" comment that described this sub-shape as unfixed
was removed.

## Tests

`test/src/folding/folded_block_keeps_next_block_start_test.dart`, new group
`A two-line block that also starts the next one.`:

- `keeps the shared line on screen when the block above it is folded` — the
  reproduction. RED before the fix (`if (a &&` directly followed by `g();`),
  GREEN after.
- `keeps the gutter and the editor in agreement on the row count`
- `round-trips losslessly`
- `glues the leading-closer two-line shape as before` — pins that the new path
  produces the same shape as the pre-existing leading-closer fold rather than a
  different one.
- `is a foldable block of its own` — pins the block list `['2..3', '3..5']`.

## Gates

- `flutter test` — all pass (see `test.md`).
- `dart analyze --fatal-infos` — no issues found.
- `dart format --output=none --set-exit-if-changed .` — 0 changed.
- `python3 tool/coverage_gate.py --min 100` — see `test.md`.
