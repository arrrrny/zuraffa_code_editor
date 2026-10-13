# Contracts: the merged invariant

## The invariant

For every `i > 0`, `ranges[i].start > ranges[i - 1].end`. Sorted, non-overlapping
**and non-adjacent**, all three in one comparison.

## Who must honour it

`HiddenRanges`'s constructor, by asserting. There is one other party and it
already does:

| Party | How it honours it |
| --- | --- |
| `HiddenRangesBuilder._merge` (`hidden_ranges_builder.dart:41-65`) | folds on `previous.end >= current.start` (`:48`), so the output always has a gap |
| `HiddenRanges.empty` (`hidden_ranges.dart:35-39`) | an empty list satisfies the invariant vacuously |
| `Code` (`code.dart:115-121`) | builds its ranges through the builder, never the constructor |
| the test suite | every file except the two deleted ones satisfies it (R4) |

## What a caller must not do

**Construct a `HiddenRanges` with touching ranges.** The constructor now
asserts, so this is a debug-mode failure rather than a silent behaviour change.
Nothing in `lib/` does it (R2), and `HiddenRanges` is not exported
(`lib/zuraffa_code_editor.dart` has no `hidden_ranges` export at all), so this is
an internal contract, not a public one.

If some future path needs to build a `HiddenRanges` without the builder, it must
merge first — `HiddenRangesBuilder(sourceMap: {}, textLength: …).copyWithRange(key, range)`
is the supported route, and it costs a map copy rather than a second invariant.

## What the guarantee buys the algorithms

`recoverPosition`'s affinity choice is unambiguous: with a gap between every
pair, at most one range collapses at any visible position, so "the first range
collapsed here" and "the last range collapsed here" are the same range. That is
precisely the fact the two deleted `while` loops were defending, and precisely
why their removal is safe rather than hopeful.

It does **not** buy `cutPosition` its interpolation accuracy: sparsity, not
adjacency, is what makes interpolation overshoot
(`hidden_ranges_interpolation_overshoot_test.dart`). Those guards stay.
