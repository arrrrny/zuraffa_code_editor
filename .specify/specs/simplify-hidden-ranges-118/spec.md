# Spec: simplify-hidden-ranges

Fork issue: #118 · Upstream: akvelon/flutter-code-editor#84
Label: `chore` · Severity: `low` · Backlog rank: 21

## What was asked

"`HiddenRangesBuilder` already merges adjacent ranges; legacy algorithms still
assume they are unmerged."

Upstream #84, in full, says more than the fork's one-line summary:

> `HiddenRanges` class was designed to allow adjacent hidden ranges.
> In #26, `HiddenRangesBuilder` was introduced that insures adjacent ranges are
> merged. This means we can simplify algorithms of cutting and recovering
> positions, texts, and highlighted.

So the chore is: adopt the merged invariant as the class's contract, and delete
the code that exists only to serve a shape the builder never produces.

## What exists today

`HiddenRanges` (`lib/src/hidden_ranges/hidden_ranges.dart`) is `@immutable` and
holds a `List<HiddenRange>` plus a precomputed
`hiddenCharactersBeforeRanges` (`:51-61`). Its constructor asserts
`_areSortedAndNotOverlapping` (`:41-49`), which is `ranges[i].isAfter(ranges[i-1])`
for every adjacent pair — sorted, non-overlapping, and **adjacency permitted**.

`HiddenRangesBuilder._merge` (`hidden_ranges_builder.dart:41-65`) sorts by
`(start, end)` and then folds whenever `previous.end >= current.start`
(`:48`), so every list the builder produces has a **strict gap**: no range ends
where the next begins. The builder is the only constructor inside `lib/`
(`hidden_ranges_builder.dart:36`), and `HiddenRanges` is **not exported** by
`lib/zuraffa_code_editor.dart` — verified, not assumed.

The code that exists to serve the adjacent shape lives in `recoverPosition`
(`hidden_ranges.dart:237-316`):

- `:273-276` — with `TextAffinity.downstream`, walk *back* over a run of ranges
  that touch, and recover `ranges[runStart].start`.
- `:280-284` — with `TextAffinity.upstream`, walk *forward* over the same run
  and recover `ranges[runEnd].end`.

Both loops are the whole implementation of "several collapsed ranges put the
cursor at different ends of the same gap depending on the affinity". With the
merged invariant a run has length one, so each loop degenerates to a no-op and
the expression after it is the answer.

## What this spec adds

One invariant, adopted deliberately and enforced, and the two branches it makes
unreachable removed:

1. The constructor assert becomes **sorted, non-overlapping, and
   non-adjacent** — with a message that names the merge as the reason.
2. `recoverPosition` no longer walks runs. `downstream` recovers
   `ranges[rangeIndex].start`, `upstream` recovers `ranges[rangeIndex].end`.
3. The two tests that construct touching ranges directly
   (`test/src/hidden_ranges/hidden_ranges_adjacent_recover_test.dart`,
   `test/src/hidden_ranges/hidden_ranges_collapse_test.dart`) are **deleted**,
   and replaced by one test asserting that the constructor now rejects a
   touching pair. Their `position` and `cut`/`recover` projections of real
   documents are already covered by `hidden_ranges_position_test.dart`,
   `hidden_ranges_selection_test.dart` and `hidden_ranges_test.dart`.

Nothing else changes. `cutString`, `cutPosition`, `cutHighlighted`,
`cutSelection`, `recoverSelection` and `cutSearchResult` keep their algorithms,
their interpolation search and their overshoot guards
(`hidden_ranges.dart:198-203`, pinned by
`test/src/hidden_ranges/hidden_ranges_interpolation_overshoot_test.dart`) — the
overshoot guards exist because interpolation can overshoot on *sparse* ranges,
which is a different shape from adjacency and is not affected by the merge.

## Decisions

- **The assert tightens; it does not warn.** A `assert` that alludes to a
  shape the class no longer supports is worse than no assert, because it reads
  as a statement about what callers may pass. The new message says both what
  the invariant is and why the merge is upstream of it.
- **The two deleted tests are not "tests that failed".** They were written to
  pin a behaviour the package is choosing to stop having, and they test it by
  constructing a list no internal caller can produce. Keeping them green means
  keeping the loops, which is the whole point of the chore. They are replaced
  rather than dropped: the new test asserts the constructor rejects the shape,
  so the invariant is itself pinned.
- **`HiddenRangesBuilder._merge` is the source of truth, so the assert is
  checked against it, not the other way round.** `_merge` already produces the
  tighter shape; the assert is the documentation of what it produces, expressed
  where the object is built. A future edit to `_merge` that stops merging will
  trip the assert in debug mode and in the full test suite, which is the
  cheapest possible alarm.
- **Adjacency is not made reachable again through the side door.**
  `HiddenRange`'s own asserts (`hidden_range.dart:18-33`) are untouched; only
  the *relation between* ranges changes.
- **No new public API, no new field, no new type.** The change is strictly
  minus code.

## Out of scope

- `HiddenRangesBuilder._merge`'s algorithm. It is already correct and it is the
  thing the new assert depends on.
- `cutPosition`'s interpolation search and its overshoot guards.
- `HiddenLineRanges` and its builder — a separate class with its own
  invariants, reachable through the public API, and not mentioned by the issue.
- Making `HiddenRanges` exported, or making its constructor private. It stays
  `@internal`-by-omission exactly as it is.
- Any change to `line_numbering_breakpoint.dart`, `code.dart`'s use of the
  builder, or the folding machinery.

## Assumptions

- **`HiddenRanges` is not part of the public API.** Verified: the barrel at
  `lib/zuraffa_code_editor.dart` exports neither it nor any `src/hidden_ranges/*`
  path, and the only `lib/` construction site is the builder. If a future
  export is added, the tightened assert becomes a breaking change and must be
  called out then — that is a future problem with a future changelog entry, not
  a reason to keep the loops.
- **Every `HiddenRanges` in the test suite outside the two deleted files is
  non-adjacent.** `test/src/hidden_ranges/common.dart` has ranges with gaps
  (`20..23`, `31..42`, …); the overshoot and position tests likewise. If the
  tightened assert trips on any of them, that is a shoal this spec did not see
  and the file must be fixed, not the assert loosened.
- **`recoverPosition`'s two loops are the only adjacency-dependent code.**
  Verified by reading `hidden_ranges.dart` end to end; `cutString` handles
  touching ranges incidentally (`position = range.end` makes the next range's
  `substringEnd` equal the current position, so nothing is written twice), so it
  needs no change and gets none.

## Functional requirements

- **FR-1** The constructor rejects a list with two touching ranges.
- **FR-2** The constructor still accepts a list with gaps, and accepts a single
  range, and accepts `HiddenRanges.empty`.
- **FR-3** The constructor still rejects an overlapping pair.
- **FR-4** `recoverPosition` with `downstream` recovers the start of the range
  that collapses at the position.
- **FR-5** `recoverPosition` with `upstream` recovers the end of that range.
- **FR-6** FR-4 and FR-5 hold for a position at the collapse of the *last*
  range, the *first* range, and a range in the middle — the three shapes the new
  assert permits, which are the three shapes that survive.
- **FR-7** Every projection the two deleted tests covered for non-adjacent
  input still holds: `cutPosition`, `cutSelection`, `recoverSelection`,
  `cutSearchResult`, `cutString` and `cutHighlighted` are unchanged, asserted by
  the existing suites in `test/src/hidden_ranges/`.
- **FR-8** A folded document still renders and still recovers the selection
  byte-for-byte: the `CodeController` folding tests pass unmodified.

## Success criteria

- **SC-1** `dart analyze --fatal-infos lib test` clean.
- **SC-2** `dart format --output=none --set-exit-if-changed .` clean.
- **SC-3** `flutter test --concurrency=2` green, with the two adjacency test
  files deleted and no other test modified.
- **SC-4** `tool/coverage_gate.py --min 100` at 100.00% with `EXEMPT_LINES`
  unchanged in count, or renumbered only for lines this change shifts.
- **SC-5** The net diff is a deletion: `git diff --shortstat` shows more removed
  lines than added.
- **SC-6** A mutation audit over the new assert reports 0 survivors, with the
  script committed under `.specify/specs/simplify-hidden-ranges-118/tdd/`.
