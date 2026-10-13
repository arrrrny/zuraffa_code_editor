# Requirements checklist: simplify-hidden-ranges

Fork issue: #118 · Upstream: akvelon/flutter-code-editor#84

## Functional requirements

- [x] **FR-1** A touching pair is rejected by the constructor. → T002
- [x] **FR-2** A gap, a single range and `empty` are accepted. → T003
- [x] **FR-3** An overlapping pair is still rejected. → T004
- [x] **FR-4** `downstream` recovers the collapsing range's start. → T005
- [x] **FR-5** `upstream` recovers that range's end. → T006
- [x] **FR-6** Both hold at the first, middle and last range. → T005, T006
- [x] **FR-7** Every other projection is unchanged. → T007, and the untouched
      existing suites
- [x] **FR-8** Folded documents render and recover as before. → T014

## Success criteria

- [x] **SC-1** `dart analyze --fatal-infos lib test` clean. → T015
- [x] **SC-2** `dart format --output=none --set-exit-if-changed .` clean. → T016
- [x] **SC-3** Suite green with the two adjacency test files deleted. → T012,
      T014
- [x] **SC-4** `tool/coverage_gate.py --min 100` at 100.00%, `EXEMPT_LINES`
      unchanged in count or renumbered only for shifted lines. → T017
- [x] **SC-5** `git diff --shortstat` shows a net deletion. → T018
- [x] **SC-6** Mutation audit 0 survivors, script committed under `tdd/`. → T019

## Non-goals, restated so the review can hold the line

- No change to `HiddenRangesBuilder._merge`.
- No change to `cutPosition`'s interpolation search or its overshoot guards —
  `hidden_ranges_interpolation_overshoot_test.dart` pins those and they are a
  different shape problem.
- No change to `HiddenLineRanges` or its builder.
- No new export, no new public type, no new field.
- No widening of a test bound to make anything pass.

## The judgement this chore makes

Deleting `hidden_ranges_adjacent_recover_test.dart` and
`hidden_ranges_collapse_test.dart` is not tidying up green tests — it is a
decision that the package no longer has the shape they test, and that the shape
they construct by hand is not reachable through `lib/` (R2). The replacement
test asserts the constructor refuses it, so the decision is pinned rather than
made invisible. If a reviewer disagrees with the decision, the fix is to restore
the loops and the two files, not to loosen the assert.
