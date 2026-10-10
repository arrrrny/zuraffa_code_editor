# Spec: folding-hides-next-block-start

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/25
(upstream akvelon/flutter-code-editor#213 — "Foldable block doesn't fold
correctly when there is another foldable block at the end of the first").

## Requirement

Folding a block must hide exactly that block's content. The reported
reproduction is:

```java
// Calculates the factorial of the number.
// The number must be >= 0.
int factorial(int n){
  if(n == 0){
    return 0;
  }

  return n * factorial(n - 1);
}void main(){
  int num = 5;
  print('Factorial of $num is ${factorial(num)}');
}
```

Line 8 — `}void main(){` — closes `factorial` and opens `main` on the same
line. Folding `factorial` made that line vanish, and with it the line number
and the fold toggle of `main`, whose body numbers stayed on screen.

## Root cause

Two defects compose:

1. `FoldableBlockList.joinIntersecting` joined blocks that merely *touch*.
   `factorial` is `2..8` and `main` is `8..11`; the old condition
   `ancestor.lastLine >= bubble.firstLine` treated line 8 as an intersection,
   so the two were joined into a single `2..11` block. Folding `factorial`
   therefore folded `main`'s whole body too.
2. `foldableBlockToHiddenRange` ended the hidden range at the closing line's
   `textRange.start`, so the line-numbering breakpoint marked that line
   hidden. Even with the blocks kept apart, the closer row — the only row that
   can carry the following block's fold toggle — was glued onto the opener.

## Acceptance

- Folding block A hides only A's content lines; the line that closes A and
  opens B stays visible and keeps its own row, its line number and its fold
  toggle.
- Blocks that touch stay separate foldable blocks, so B can still be folded
  on its own.
- Blocks that genuinely cross (one ends strictly inside the other) are still
  joined, exactly as before.
- Blocks that share a first line are still joined — the gutter renders one
  fold toggle per row.
- The default glued-closer layout is unchanged elsewhere: `parsers: [` still
  folds to `parsers: [  ],`.
- Folding and unfolding round-trips losslessly.
- No regression: full suite green, `dart analyze` clean, format clean.

## Non-goals

- Changing the upstream contract that a folded block leaves its closing line
  on screen. That contract predates this issue and is covered by
  `test/src/folding/folded_closing_line_test.dart`.
- Per-visual-row line numbers.
