# Bug Assessment: Folding a block hides the next block's start when they share a line

- **Slug**: folding-hides-next-block-start-99
- **Created**: 2026-10-11
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/99
  (upstream akvelon/flutter-code-editor#213)
- **Verdict**: likely valid, needs reproduction — **reproduced below in the
  two-line adjacency shape**; the multi-line shape from the upstream report is
  already fixed on master
- **Severity**: medium

## Report (verbatim or summarized)

Folding a block whose closing line is the opening line of the next block hides
the next block's first line too. Block-adjacency logic in the hidden-range
calculation. Points at `lib/src/folding/foldable_block.dart`.

## Symptom

When a foldable block's last line is also the first line of the following
foldable block, folding the upper block makes the shared line — and with it the
following block's start, line number and fold toggle — disappear. In the
two-line shape the shared line's *text* is removed from the editor, so the
visible code reads as corrupted (`if (a &&` directly followed by the body).

## Reproduction

Java source (0-based lines):

```
0  void f() {
1    int value = 1;
2    if (a &&
3        b) {      <- closes the parentheses block (2..3), opens the braces block (3..5)
4      g();
5    }
6  }
```

Fold the parentheses block (`foldAt(2)`). Observed on master:

```
void f() {
  int value = 1;
  if (a &&
    g();
  }
}
```

Line 3 — `b) {` — is gone. Breakpoint dump: `LineNumberingBreakpoint: 4 -> 3`,
`visibleLineNumbers: [0, 1, 2, 4, 5, 6, 7]` — full line 3 maps to no visible
row. The braces block (3..5) loses its first line, and the gutter has no row to
hang its fold toggle on.

The upstream report's multi-line reproduction (`}void main(){` closing
`factorial` and opening `main` with content lines between) does **not**
reproduce: fork issue #25 fixed it via PR #56 (merged 2026-10-10, master
`b166e20`). Issue #99 was filed 2026-10-10T23:13, ~18h after that merge, and is
a re-report of the same upstream defect — but the reported condition still
reproduces whenever the shared line cannot keep a row of its own.

## Suspected Code Paths

- `lib/src/code/code.dart` — `foldableBlockToHiddenRange` (the hidden-range end)
  and its `_startsAnotherFoldableBlock` guard; `_isClosingLine`.
- `lib/src/folding/foldable_block.dart` — `joinIntersecting` (already keeps
  touching blocks separate on master; verified: blocks are `[0..6, 2..3, 3..5]`).
- `lib/src/hidden_ranges/*` — `HiddenRange` asserts `end > start`, so an empty
  range is not representable; a two-line block cannot fold to "nothing hidden".

## Root Cause Hypothesis

`foldableBlockToHiddenRange` computes the hidden-range end in two steps:

1. `_isClosingLine(lastLine)` — a line whose first non-whitespace character is
   `)`, `]` or `}` — stops the range at the shared line's start, so a leading
   closer (`}void main(){`) keeps its text on screen (glued onto the opener row).
   A shared line that merely *ends* with a closer (`      b) {`) fails this
   heuristic, so the range runs through the end of the line and the line is
   hidden whole.
2. The `_startsAnotherFoldableBlock` guard gives the closer a row of its own by
   ending the range one character before it — but only when there is a content
   line between the opener and the closer (`closerOnItsOwnRow > startOfRange`).
   With a two-line block the two positions coincide, the guard is inert, and the
   two shapes fold inconsistently: `}`-leading shared line survives, `b) {`-style
   shared line vanishes.

The earlier PR #56 documented this exact sub-shape as a known limitation
("That sub-shape wants its own fix, not a widening of this narrow guard") in
`lib/src/code/code.dart`. This assessment picks that fix up.

## Proposed Remediation

In `foldableBlockToHiddenRange`, when the block's last line starts another
foldable block and the closer cannot get a row of its own
(`closerOnItsOwnRow <= startOfRange`), end the range at the shared line's start
instead of hiding the line whole — the same glued-on-one-row outcome the
`}`-leading shape already produces. `HiddenRange` forbids empty ranges, so
gluing is the closest representable shape; the shared line's text stays on
screen, which is what the issue reports as lost.

Guard the fallback with `lastLine.textRange.start > startOfRange` so degenerate
single-line blocks keep the existing upstream behavior.

## Risks & Considerations

- The change only affects blocks whose last line also starts another foldable
  block. Every other fold (including the established glued closer
  `parsers: [` → `parsers: [  ],`) is untouched.
- The multi-line shape fixed by #56 must keep the closer's own row — the guard
  change must not widen that path.
- A glued row carries the opener's line number; the following block's toggle
  still has no dedicated row to hang on in the two-line shape. That row-sharing
  is inherent to two-line folding (upstream glues `method(){}` the same way) and
  is out of scope for this issue, which reports the line being *hidden*.

## Open Questions

- None blocking. The gutter-side toggle placement for a glued row could be a
  follow-up if the maintainers want the following block foldable from the folded
  view of a two-line block.
