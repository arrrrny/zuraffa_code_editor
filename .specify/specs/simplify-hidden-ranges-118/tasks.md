# Tasks: simplify-hidden-ranges

Ordered. Test tasks first, RED before the implementation.

## Write the tests (RED)

- [x] **T001** `test/src/hidden_ranges/hidden_ranges_merge_invariant_test.dart` —
  fixture: three small `HiddenRanges` values, one with gaps, one with a single
  range, one built from `HiddenRanges.empty`. A `_collapse(...)` helper that
  builds a list of one-range-per-line shapes.
- [x] **T002** FR-1: `expect(() => HiddenRanges(ranges: [touching], …), throwsA(isA<AssertionError>()))`.
      Assert the **message** names the merge, so a future loosening cannot pass
      by keeping the assert and changing its text.
- [x] **T003** FR-2: gap / single / `empty` all construct.
- [x] **T004** FR-3: an overlapping pair still throws.
- [x] **T005** FR-4 + FR-6: `recoverPosition(…, downstream)` returns the start of
      the collapsing range, for a collapse at the first range, at a middle
      range, and at the last range.
- [x] **T006** FR-5 + FR-6: the same three positions with `upstream`, returning
      that range's end.
- [x] **T007** FR-7: `cutPosition` / `cutSelection` / `recoverSelection` /
      `cutSearchResult` / `cutString` on the gapped fixture, moved over from the
      two files being deleted — every one of their non-adjacent assertions.
- [x] **T008** The `hashCode` group from
      `hidden_ranges_collapse_test.dart:73+`: equal lists and equal text lengths
      hash equal, and a differing text length does not.
- [x] **T009** Run: `flutter test test/src/hidden_ranges
    --concurrency=2`. **T002 must fail** (no assert yet) and **T005/T006 must
    pass** (the loops still handle the single-range case correctly). T009 is
    the RED boundary: the invariant is new, the recovery is not.

## Implement

- [x] **T010** Add `_areSortedMergedAndNonAdjacent` and rewire the constructor
      assert in `hidden_ranges.dart` (`plan.md` §1). Delete
      `_areSortedAndNotOverlapping`.
- [x] **T011** Delete the two run-walking loops in `recoverPosition` and return
      `range.start` / `range.end` directly (`plan.md` §2).
- [x] **T012** Delete `test/src/hidden_ranges/hidden_ranges_adjacent_recover_test.dart`
      and `test/src/hidden_ranges/hidden_ranges_collapse_test.dart`.
- [x] **T013** Run: `flutter test test/src/hidden_ranges --concurrency=2` → green.
- [x] **T014** Run `flutter test --concurrency=2` — the whole suite, green. The
      tightened assert must trip on **no** file outside the two deleted ones;
      if it does, the file is wrong, not the assert (R4).

## Gate

- [x] **T015** `dart analyze --fatal-infos lib test` clean.
- [x] **T016** `dart format --output=none --set-exit-if-changed .` clean.
- [x] **T017** `bash /tmp/gate.sh /Users/arrrrny/Developer/zuraffa_118
      /tmp/gate118.log` → `--min 100`, `EXEMPT_LINES` unchanged in count.
      `hidden_ranges.dart`'s line numbers will shift, so any pinned exemption
      needs renumbering and a commit message that says so.
- [x] **T018** `git diff --shortstat` shows a net deletion (SC-5). If it does
      not, stop and find the scope creep.
- [x] **T019** Mutation audit, script committed at
      `.specify/specs/simplify-hidden-ranges-118/tdd/mutation_audit.py`. Minimum
      set:

  | # | Mutation | Must be killed by |
  | --- | --- | --- |
  | M1 | assert uses `start < previous.end` (overlap only) | T002 |
  | M2 | assert uses `start != previous.end` (adjacency only, overlap allowed) | T004 |
  | M3 | assert is removed entirely | T002 |
  | M4 | the predicate returns `true` unconditionally | T002, T003 |
  | M5 | `downstream` returns `range.end` instead of `range.start` | T005 |
  | M6 | `upstream` returns `range.start` instead of `range.end` | T006 |
  | M7 | `downstream` returns `ranges[0].start` (the first range always) | T005's middle and last cases |
  | M8 | `upstream` returns `ranges.last.end` (the last range always) | T006's first and middle cases |

- [x] **T020** Fill `.specify/specs/simplify-hidden-ranges-118/tdd/verification.md`.

## Ship

- [x] **T021** `CHANGELOG.md` — `## Unreleased` entry under **Changed**, noting
      that a directly-constructed adjacent list now fails an assert and that
      nothing in `lib/` builds one.
- [ ] **T022** Commit, push `chore/simplify-hidden-ranges-118`, open the PR
      against `master`. **Do not merge.**
