# Research: simplify-hidden-ranges

Fork issue: #118 · Upstream: akvelon/flutter-code-editor#84
Each item is a claim checked against the code, with the check named.

## R1 — The two invariants, and which one the class currently promises

Checked: `lib/src/hidden_ranges/hidden_ranges.dart:22-27`,
`lib/src/hidden_ranges/hidden_range.dart:52-57`,
`lib/src/code/text_range.dart:10-11`,
`lib/src/hidden_ranges/hidden_ranges_builder.dart:41-65`.

`HiddenRanges`'s constructor asserts `_areSortedAndNotOverlapping`
(`hidden_ranges.dart:41-49`), which is:

```dart
for (int i = ranges.length; --i >= 1;) {
  if (!ranges[i].isAfter(ranges[i - 1])) {
    return false;
  }
}
```

and `MyTextRange.isAfter` (`text_range.dart:10`) is `start >= other.end`. So the
assert permits a range that **starts exactly where the previous one ends** — the
touching shape. Sorted, non-overlapping, adjacency allowed.

`HiddenRangesBuilder._merge` (`hidden_ranges_builder.dart:44-62`) sorts by
`(start, end)` and folds on `previous.end >= current.start` (`:48`), then
`removeAt(i); i--`. Folding on `>=` rather than `>` is what makes the output
strictly non-adjacent: after a pass, every pair satisfies
`ranges[i].start > ranges[i - 1].end`.

So the class currently promises a weaker invariant than its only producer
maintains. That gap *is* the chore.

## R2 — The builder is the only producer, and the class is not exported

Checked: `grep -rn "HiddenRanges(" lib/` — exactly one construction site,
`hidden_ranges_builder.dart:36`. `lib/src/code/code.dart` and
`lib/src/hidden_ranges/hidden_line_ranges*.dart` interact with the builder and
with `HiddenRange`, not with the `HiddenRanges` constructor.

Checked: `grep -n "hidden_range" lib/zuraffa_code_editor.dart` — **no match at
all**. The barrel exports `src/code/code.dart`, `src/code_field/*`,
`src/folding/*` and the rest, and nothing under `src/hidden_ranges/`. So
neither `HiddenRange` nor `HiddenRanges` is public API in this fork, despite
`HiddenRange` being exported upstream.

So tightening the assert changes nothing a host can reach through the public
API. It changes the *internal* contract only — which is exactly the scope this
chore should have.

## R3 — The code that exists only for the touching shape

Checked: `lib/src/hidden_ranges/hidden_ranges.dart` read end to end, 378 lines.

`recoverPosition` (`:237-316`) has the only adjacency-dependent code:

```dart
case 0: // position is at the range collapse.
  switch (placeHiddenRanges) {
    case TextAffinity.downstream:
      // Find the first range collapsed at this point.
      while (rangeIndex > 0 &&
          ranges[rangeIndex - 1].end == ranges[rangeIndex].start) {
        rangeIndex--;
      }
      return ranges[rangeIndex].start;
    case TextAffinity.upstream:
      // Find the last range collapsed at this point.
      while (rangeIndex < ranges.length - 1 &&
          ranges[rangeIndex].end == ranges[rangeIndex + 1].start) {
        rangeIndex++;
      }
      return ranges[rangeIndex].end;
  }
```

Both loops test adjacency — `end == next.start`. Under the merged invariant
the condition is false on the first iteration for both, so each loop is a
no-op and the `return` after it is already the answer. Removing the loops is
not a change in behaviour for builder-produced lists; it is the deletion of
two dead branches and the comments that explain them.

Everything else in the file is shape-independent:

- `cutString` (`:66-101`) — `position = range.end` at `:91` makes the next
  range's `substringEnd` equal the current position, so nothing is written
  twice whether or not ranges touch. No change needed, and verified by the
  `cutString` cases in `hidden_ranges_test.dart`.
- `cutHighlighted` (`:119-167`) — walks the tree and cuts by offset; no
  adjacency assumption.
- `_getHiddenCharactersBeforeRanges` (`:51-61`) — a prefix sum, one entry per
  range plus the total.
- `cutPosition` (`:173-229`) — interpolation search. Its `rangeIndex <
  lowerRange` / `> upperRange` guards (`:198-203`) look like they might be
  adjacency-related and are **not**: they guard interpolation overshoot on
  sparse ranges. There is a dedicated test,
  `test/src/hidden_ranges/hidden_ranges_interpolation_overshoot_test.dart`,
  whose doc says so explicitly. Left alone.
- The final `switch` at `:309-315` — "there is only one range", reachable when
  `upperRange == lowerRange`, which happens for a single-range list. Not
  adjacency.

## R4 — Which tests pin the touching shape

Checked: every `HiddenRanges(` site under `test/`, 18 of them.

Two files construct touching ranges, and only these two:

- `test/src/hidden_ranges/hidden_ranges_adjacent_recover_test.dart` — three
  ranges, the first two touching (`10..12`, `12..15`), plus a gap to `30..40`.
  Its own doc explains the run-walking semantics.
- `test/src/hidden_ranges/hidden_ranges_collapse_test.dart` — `_adjacentRanges`
  with `[10..11) [11..12)` and, in one case, a three-long run
  `[10..11) [11..12) [12..13)`.

Every other site has gaps: `common.dart` (`20..23`, `31..42`, `67..91`, …),
`hidden_ranges_test.dart`, `hidden_ranges_position_test.dart`,
`hidden_ranges_interpolation_overshoot_test.dart`,
`hidden_ranges_selection_test.dart`, `cut_search_result_test.dart`,
`code_hidden_ranges_test.dart` (`57..76`, `81..100`),
`hidden_line_ranges_builder_test.dart`.

Consequence: the tightened assert should trip on **zero** existing files
besides those two, and if it trips anywhere else that is a shoal, not a reason
to loosen the assert.

## R5 — The net effect, measured

`recoverPosition` loses two `while` loops, their two comments and the
`switch` arms' nesting: 12 lines out of a 378-line file, plus a 6-line assert in
the constructor and a new test. `git diff --shortstat` must show a net removal
(SC-5), and anything else is a rewrite wearing a chore's label.

## R6 — What this does not touch

- `HiddenRangesBuilder._merge`. It is the producer of the invariant; changing
  it would change the shape the assert is about to claim.
- `HiddenLineRanges` / `HiddenLineRangesBuilder` — a line-indexed type with its
  own lifecycle, exported publicly through `HiddenRange`, and not mentioned by
  the issue.
- `line_numbering_breakpoint.dart`, `code.dart`'s hidden-range plumbing, and
  the folding machinery.
