# Cycle log: folding-hides-next-block-start

## Red

`test/src/folding/folded_block_keeps_next_block_start_test.dart` written
against master `5188d5f` with the issue's exact reproduction text.

A probe first confirmed the root cause. On unmodified master, folding
`factorial` yields:

```
BLOCKS: [0..1, 2..11, 3..5]
folded text: int factorial(int n){}
cut(8) = null
```

`joinIntersecting` had already swallowed `main` into `factorial`: the two
touching blocks became one `2..11` block, and folding it hid `main`'s opener
row and its whole body. That is exactly the second screenshot in the issue —
line 9 `}void main(){` had lost its number and its fold toggle.

## Attempt 1 — too broad

The first attempt only changed `foldableBlockToHiddenRange` to always end the
range before the closing line, so *every* closer kept its own row. That made
the visible text of every folded block change (`method1(){` + `}` on separate
rows instead of `method1(){}`) and broke ~25 tests whose snapshots encode the
glued closer as intended behaviour. Reverted: the issue is not "the closer
should sit on its own row", it is "the closer that also opens the next block
must not be hidden".

## Green — part 1: `joinIntersecting`

`areIntersecting` became `areCrossing`:

```dart
final areCrossing =
    ancestor.lastLine > bubble.firstLine &&
    ancestor.lastLine < bubble.lastLine;
```

Touching blocks (`8..11` starts exactly where `2..8` ends) no longer join.
A `shareFirstLine` condition was added so two blocks opening on the same line
still merge — the gutter renders one fold toggle per row, so two blocks
cannot share one.

Result with part 1 alone: `BLOCKS: [0..1, 2..8, 3..5, 8..11]` and the folded
text still glued the closer onto the opener
(`int factorial(int n){}void main(){`), which left `main`'s fold toggle on
the folded block's row and line 8 without a row of its own.

## Green — part 2: the narrow range guard

```dart
if (_isClosingLine(lastLine) && _startsAnotherFoldableBlock(block)) {
  final closerOnItsOwnRow = lastLine.textRange.start - 1;
  if (closerOnItsOwnRow > startOfRange) {
    endOfRange = closerOnItsOwnRow;
  }
}
```

`_startsAnotherFoldableBlock` looks for a foldable block whose `firstLine` is
this block's `lastLine`. Ending one character earlier leaves the newline that
terminated the previous content line outside the range, and that newline
becomes the row break the closer needs. The guard is deliberately narrow:
`parsers: [` still folds to `parsers: [  ],`, and every other closer still
glues onto its opener, so the change is invisible outside the reported shape.

Result: `int factorial(int n){\n}void main(){`, visible lines
`[0,1,2,8,9,10,11,12]`, `cutLineIndexIfVisible(8) == 3`, three fold toggles in
the gutter.

## Expectation updates

Eight previously-green tests had encoded the old merge. Each was re-run and
its expected list replaced with the actual separate-block form — the Go
parser (3 examples), the Scala parser (1), the Java parser (4 including the
"All types of foldable blocks are recognized" list), and the
"Intersecting blocks" list in `foldable_block_test.dart`. No expectation was
changed to make a genuine failure pass; in every case the old expectation
described two blocks as one.

Note the folded text of `main` itself is unchanged: `}void main(){}` — the
closer of `main` is not the opener of another block, so it still glues.

## Refactor

- The two-part fix is left as two changes in two files rather than one guard,
  because they answer different questions: "which blocks exist" and "what a
  folded block hides".
- The new test file uses named constants (`foldedFactorialText`,
  `foldedMainText`) rather than inline multi-line literals so both the
  folded-`factorial` and the folded-`main` expectations read the same way.
