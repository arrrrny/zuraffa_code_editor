# Requirements checklist: cache-text-span

Fork issue: #114 · Upstream: akvelon/flutter-code-editor#127

## Functional requirements

- [x] **FR-1** Two unchanged consecutive calls return the same object. → T002
- [x] **FR-2** A no-op notification still hits. → T003
- [x] **FR-3** Text change invalidates. → T004
- [x] **FR-4** Fold / unfold invalidates. → T005
- [x] **FR-5** Style change invalidates. → T006
- [x] **FR-6** Theme change invalidates, in both the ancestor and no-ancestor
      cases. → T007
- [x] **FR-7** Search pattern, match navigation and close each invalidate. → T008
- [x] **FR-8** Language change invalidates. → T009
- [x] **FR-9** An active search does not accumulate leaves across calls. → T011
- [x] **FR-10** The composing path is not served from the cache. → T010
- [x] **FR-11** A hit's tree is structurally what a miss builds. → T012
- [x] **FR-12** `lastTextSpan` is assigned on every call. → T013
- [x] **FR-13** The no-language path is cached and invalidates on text. → T009

## Success criteria

- [x] **SC-1** `dart analyze --fatal-infos lib test` clean. → T022
- [x] **SC-2** `dart format --output=none --set-exit-if-changed .` clean. → T023
- [x] **SC-3** Every pre-existing test passes unmodified. → T021
- [x] **SC-4** `tool/coverage_gate.py --min 100` at 100.00%, `EXEMPT_LINES`
      unchanged in count, renumbered only for lines this change shifts. → T024
- [x] **SC-5** Mutation audit reports 0 survivors, script committed under
      `tdd/`. → T025
- [x] **SC-6** New test file written RED before the implementation. → T001–T014

## Non-goals, restated so the review can hold the line

- No configurability: no flag to disable the cache, no way to observe it.
- No multi-entry cache, no statistics, no warm-up.
- No change to `SpanBuilder`, `SearchResultHighlightedBuilder`,
  `HiddenRanges.cutSearchResult` or the folding machinery.
- No parse cache.

## Conformance matrix

`code_matrix.md`.
