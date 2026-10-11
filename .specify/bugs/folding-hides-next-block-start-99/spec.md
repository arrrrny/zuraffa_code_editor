# Spec: folding-hides-next-block-start-99

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/99
(upstream akvelon/flutter-code-editor#213 — re-reported; the multi-line
reproduction was fixed by fork issue #25 / PR #56, the two-line shape below is
what still reproduces).

## Requirement

Folding a block must hide exactly that block's content. The line that closes a
block and opens the next one must stay on screen — it is the next block's first
line, and it carries the next block's fold toggle.

The reported reproduction is the two-line adjacency shape:

```java
void f() {
  int value = 1;
  if (a &&
      b) {
    g();
  }
}
```

Line 3 — `b) {` — closes the parentheses block (`2..3`) and opens the braces
block (`3..5`). Folding the parentheses block removed line 3 from the editor
entirely, so the visible text read `if (a &&` directly followed by `g();`.

## Root cause

`foldableBlockToHiddenRange` (lib/src/code/code.dart) picks the hidden-range end
from two rules:

1. `_isClosingLine(lastLine)` — true only when the line *starts* with `)`, `]`
   or `}` — stops the range at the shared line, keeping its text on screen. The
   shared line `      b) {` ends with the closer but does not start with one, so
   the heuristic fails and the range runs through the whole line.
2. The `_startsAnotherFoldableBlock` guard ends the range one character before
   the shared line so it keeps a row of its own — but only when a content line
   sits between the opener and the closer. A two-line block has none
   (`closerOnItsOwnRow == startOfRange`), so the guard is inert and the line is
   hidden whole.

## Acceptance

- Folding the two-line touching block keeps the shared line's text on screen
  (`b) {` is visible, glued onto the opener's row — the shape a `}`-leading
  shared line already folds to).
- The gutter and the editor still agree on the row count
  (`visibleLineNumbers.length == visibleText` rows).
- Fold/unfold round-trips the full text losslessly.
- The leading-closer two-line shape (`}void main(){`) keeps its current folded
  output.
- The multi-line shape from #25 keeps the closer's own row, its line number and
  its fold toggle (pinned by `folded_block_keeps_next_block_start_test.dart`).
- No regression: full suite green, `dart analyze` clean, `dart format` clean,
  coverage gate at 100%.

## Non-goals

- Giving a glued two-line block's following block its own gutter row/toggle — a
  `HiddenRange` cannot be empty (`assert(end > start)`), so a two-line fold
  always shares a row; upstream glues `method(){}` the same way.
- Widening `_isClosingLine`, which would change how non-touching two-line
  blocks fold.
