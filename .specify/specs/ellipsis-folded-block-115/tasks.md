# Tasks: ellipsis-folded-block

**Input**: Design documents from `.Users/arrrrny/Developer/zuraffa_115/.specify/specs/ellipsis-folded-block-115/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/folded-line-ellipsis.md, quickstart.md

**Tests**: TDD is mandatory for this feature (the repo's TDD profile is raw
`flutter test`; the coverage gate is 100%). Every task below therefore has its
tests written and run RED before its implementation tasks. The RED evidence goes
in `tdd/verification.md` as it is produced, not reconstructed afterwards.

**Organization**: Tasks are grouped by user story so each is independently
testable. The spec has no separate "user stories" section — the stories below are
derived from its acceptance criteria.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

Single Flutter package. Paths are repository-root relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: confirm the working state, and prove the folding and span-tree
regression nets are intact before anything is touched.

- [ ] T001 In `/Users/arrrrny/Developer/zuraffa_115`, confirm `git log --oneline -1` is the plan commit and the tree is clean, then `flutter pub get`.
- [ ] T002 Run `flutter test --concurrency=2 test/src/code_field/span_builder_test.dart test/src/folding/folded_closing_line_test.dart test/src/folding/folded_block_keeps_next_block_start_test.dart` and confirm all pass **unmodified**. These three files are the regression net: they pin what a folded line looks like as text, what the unfolded tree looks like, and the two awkward fold shapes. If one fails now, stop and investigate before writing anything — it means the rebase onto #116's merge broke something.
- [ ] T003 [P] Read `lib/src/code_field/span_builder.dart` end to end, `lib/src/highlight/node.dart:55-70` and `lib/src/highlight/result.dart:44-46` (the `splitLines` invariant the splice depends on), `lib/src/hidden_ranges/hidden_line_ranges.dart:58-77` (the two maps), `lib/src/code/code.dart:636-717` (what a fold leaves on screen), and the six fixtures in `quickstart.md` §3 — as the fixture and whole-tree-assertion patterns to mirror.
- [ ] T004 Record the current `EXEMPT_LINES` contents of `tool/coverage_gate.py` and the test count of the three regression files, so the RED run and the coverage run can be told apart from drift later.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the kept-line derivation and the terminating-node splice. No story
can be delivered without these.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

### Tests (write first, must fail)

- [ ] T005 [P] Create `test/src/code_field/fold_ellipsis_test.dart` with the `config` fixture from `test/src/folding/folded_closing_line_test.dart:30-50` and two tests:
  `shows an ellipsis at the end of the kept line of a folded block` — folds at line 2 (`  parsers: [`) through `controller.foldAt(2)`, pumps a field, and asserts `controller.lastTextSpan!.toPlainText()` contains `'  parsers: [  ], …'`; and
  `shows no ellipsis when nothing is folded` — the same fixture unfolded, asserts the span tree's plain text equals `controller.text`.
  Run `flutter test --concurrency=2 test/src/code_field/fold_ellipsis_test.dart` — RED, because no marker exists yet.
- [ ] T006 [P] Add one entry to the `_examples` map in `test/src/code_field/span_builder_test.dart` for the shared-row fold: the `config` source folded at line 2, built through `Code(text:, highlighted:, language: java)` then `code.foldedBlock(block)` and `SpanBuilder(code:, theme:, rootStyle: _default)`, asserting the whole expected tree by hand. RED. This is the test that pins the marker's *position*, not just its presence — write the expected tree out in full, in the file's existing style, and do not approximate it.

### Implementation

- [ ] T007 In `lib/src/code_field/span_builder.dart`, derive the kept visible lines once at the top of `build()` (`span_builder.dart:18`, beside the `_visibleLineIndex = 0` reset at `:19`): for each entry of `code.foldedBlocks`, `code.hiddenLineRanges.cutLineIndexIfVisible(block.firstLine)`, keeping the non-null values in a `Set<int>`. Discarding the nulls there is what makes the splice itself branch-free; the null is reachable and is covered by T017.
- [ ] T008 In `_buildNode` (`span_builder.dart:50-69`), splice the marker: when the node starts on a kept visible line (the value of `_visibleLineIndex` at entry — `_updateLineIndex` runs at `:58`, *after* `_paleIfRequired` at `:56`) and the node's own `value` ends with `'\n'`, append `TextSpan(text: ' …', style: rootStyle ?? style)` as the node's last child, after `_buildList`'s result. A private top-level constant holds the marker string.
- [ ] T009 In `build()`, handle the final-line-without-a-newline case: a kept line that is also the last visible line is terminated by no node's own value (`node.dart:55-70` leaves the last piece without a `'\n'`), so the marker goes on the last span of the walk, guarded so it is inert unless the last visible line is a kept line.
- [ ] T010 Run `flutter test --concurrency=2 test/src/code_field/fold_ellipsis_test.dart test/src/code_field/span_builder_test.dart` — GREEN. Then re-run the three regression files from T002 and confirm they are still all green.

**Checkpoint**: the marker exists, it is in the right place, and nothing else in the tree moved.

---

## Phase 3: User Story 1 - The marker is on the kept line, wherever the fold left the text (Priority: P1) 🎯 MVP

**Goal**: a host that folds any block sees an ellipsis exactly where the text
stopped, in every shape `foldableBlockToHiddenRange` can produce.

**Independent Test**: fold the `parsers: [` fixture, the `}void main(){` fixture
and a comment-block-with-no-trailing-newline fixture; each renders one marker in
the right place, and the own-row closer renders none on its own row.

### Tests (write first, must fail)

- [ ] T011 [P] [US1] Add `puts the ellipsis after the closer when the closer shares the kept row` — the `config` fixture folded at line 2, asserting the plain text contains `'parsers: [  ], …'` and *not* a bare `'parsers: [ …'`. RED.
- [ ] T012 [P] [US1] Add `puts no ellipsis on the closer's own row when the closer gets a row of its own` — the `}void main(){` source from `test/src/folding/folded_block_keeps_next_block_start_test.dart:32-54`, folded at line 2, asserting the marker is on the `int factorial(int n){` row and that the `}void main(){` row's text is followed by a newline, not by a marker. RED — this is the test that catches a marker appended to whatever node the walk ended on.
- [ ] T013 [P] [US1] Add `shows the ellipsis on a kept line that is the last line with no trailing newline` — the `'// one\n// two\n// three'` comment block folded at line 0, asserting the marker is present and that the plain text is exactly `'// one …'`. RED — this is the test for T009's second splice, and without it that branch is dead code the coverage gate will reject.

### Implementation

- [ ] T014 [US1] No implementation change: T007–T009 make T011–T013 GREEN. If T012 is RED with the marker on the closer's row, the terminating-node rule is wrong — check that the splice is judged on the node's *own* value ending in `'\n'`, not on the walk's position. If T013 is RED, T009's guard is inverted.
- [ ] T015 [US1] Run `flutter test --concurrency=2 test/src/code_field/fold_ellipsis_test.dart` — GREEN. Then re-run the three regression files.

**Checkpoint**: US1 is fully functional and independently testable. This is the MVP.

---

## Phase 4: User Story 2 - The buffer never moves (Priority: P1)

**Goal**: the marker is paint-only, in every direction — through a fold, an
unfold, an edit and a re-parse — and one marker appears per kept line.

**Independent Test**: fold, unfold, and type on the kept line; `controller.text`
returns to the original byte-for-byte each time, and the marker count equals the
number of visible folded blocks.

### Tests (write first, must fail)

- [ ] T016 [P] [US2] Add `leaves controller.text byte-for-byte unchanged by folding and unfolding` — the `config` fixture: capture `controller.text` before, fold at line 2, assert it equals the folded text `folded_closing_line_test.dart:36-50` pins, unfold, and assert it equals the original again. RED if the marker ever enters `visibleText`.
- [ ] T017 [P] [US2] Add `drops the ellipsis when the block is unfolded` — fold then `controller.unfoldAt(2)`, and assert the span tree's plain text equals `controller.text` with no `'…'` anywhere. RED.
- [ ] T018 [P] [US2] Add `keeps the ellipsis across a re-parse` — fold at line 2, then type a character on the kept line (`controller.text` edit through the field, as `per_line_background_test.dart` does), pump, and assert the marker is still at the end of the kept line. RED if the derivation is computed once and cached, or if `foldedAs` (`code.dart:744`) loses the fold.
- [ ] T019 [P] [US2] Add `shows one marker per kept line when a nested fold is swallowed` — the #213 fixture with `foldAt(2)` then `foldAt(3)`, which leaves the visible value equal to folding 2 alone (`folded_block_keeps_next_block_start_test.dart:121-134`). Assert exactly one marker, on the `int factorial(int n){` row. RED if the null from `cutLineIndexIfVisible` (`hidden_line_ranges.dart:65`) is not discarded.
- [ ] T020 [P] [US2] Add `shows a marker on each of two nested folds` and `shows a marker on each of two adjacent folds` — the first on a block nested inside a *visible* kept line (fold a `if` block inside a method body, both kept lines visible), the second on `foldAt(2)` plus `foldAt(8)` of the #213 fixture. Two markers each, in line order. RED.

### Implementation

- [ ] T021 [US2] No implementation change expected: T016–T020 are assertions about the splice, and T007–T009 already satisfy them. A RED in T018 means the derivation must move inside the build rather than being cached on the builder — `SpanBuilder` is constructed per `_createTextSpan` call (`code_controller.dart:1369-1373`), so the fix is to keep it there. A RED in T019 means the nulls are being kept.
- [ ] T022 [US2] Run the whole file `flutter test --concurrency=2 test/src/code_field/fold_ellipsis_test.dart` — GREEN. Re-run the three regression files.

**Checkpoint**: US1 and US2 both work independently, and the buffer is provably untouched.

---

## Phase 5: User Story 3 - Styling, the search path and the bypasses (Priority: P2)

**Goal**: the marker looks like part of the field rather than part of the token
it follows, it survives the search-match build path, and the two paths that
bypass `SpanBuilder` are documented-by-test rather than assumed.

**Independent Test**: fold a document whose kept line ends inside a string
literal; the marker is rendered in the base style, not the string's. Folding with
a search match active carries the marker through as one unstyled leaf.

### Tests (write first, must fail)

- [ ] T023 [P] [US3] Add `styles the ellipsis with the base style, not the token style` — a fixture whose kept line ends inside a string literal or a comment, folded, asserting the marker span's `style` is the `rootStyle` handed to `SpanBuilder` (`span_builder.dart:12`) and not the token's style. RED if the splice falls back to the node's style unconditionally.
- [ ] T024 [P] [US3] Add `With no base style the marker falls back to the line style` — the same fixture built with `rootStyle: null`, asserting the marker's style is the style of the leaf it follows. RED if the fallback is missing; a marker with a different style from its line would paint at different metrics.
- [ ] T025 [P] [US3] Add `A match after a folded line still lands on its own text` — fold a document, run a search whose match sits below the folded line, and assert the highlighted leaves join to the match text. This is the test that found the interaction: with the marker in the tree the highlight lands two characters early, on `  two` instead of `two()`, because match offsets are cut against `code.text` (`hidden_ranges.dart:356-367`).
- [ ] T026 [P] [US3] Add `shows no ellipsis when no language is set` — a controller with `language: null`, asserting the span tree has no marker and no fold machinery at all. RED only if the splice was placed somewhere that runs without a language.
- [ ] T027 [P] [US3] Add `no ellipsis while an IME composition is active` — start a composition on the folded document and assert the span built during composition has no marker. RED if the marker was routed through a path that survives `super.buildTextSpan` (`code_controller.dart:1338-1347`).

### Implementation

- [ ] T028 [US3] Add the search switch, the one implementation change the search test forced: `SpanBuilder.withFoldEllipsis` (`span_builder.dart:41-48`, default `true`) gates both splices, and `CodeController.buildTextSpan` passes `visibleSearchResult.matches.isEmpty` (`code_controller.dart:1351`). `_createTextSpan` forwards it (`code_controller.dart:1374-1380`).
- [ ] T029 [US3] Confirm T023–T027 GREEN. The composition and no-language paths need no change of their own — both bypass `SpanBuilder` — and the search test goes GREEN only with T028 in place.

**Checkpoint**: all stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: the gates this repo enforces, and the PR.

- [ ] T030 Run the CI-identical coverage gate from `quickstart.md` §4. Must read `Coverage gate: 100.00% >= 100.00% — OK`. If the known host flake (`quickstart.md` §7) reds, re-run that file alone and record it in the PR body; do not widen its bound.
- [ ] T031 If any new branch is unreachable, prove it dead and add it to `EXEMPT_LINES` in `tool/coverage_gate.py` **with a written reason**, renumbering by line number — the tool pins by line, so any insertion above an exempted line shifts it. Check the count against T004's record first.
- [ ] T032 `dart analyze --fatal-infos` and `dart format --output=none --set-exit-if-changed .` both silent.
- [ ] T033 [P] Add a CHANGELOG.md entry for the marker, above the existing entries, in the style of the `currentLineColor` entry.
- [ ] T034 Write `tdd/verification.md`: the RED evidence per test, the naming of the mutants and their kill status, and the coverage-gate number. Mutation candidates for this spec, all of which must be killed: `M-noSplice` (remove the append), `M-midLine` (append to every node on the kept line), `M-lineZero` (kept line always 0), `M-keepAfterUnfold` (never recompute the derivation), `M-tokenStyle` (always use the node's style), `M-keepNulls` (do not discard the nulls from `cutLineIndexIfVisible`), `M-lastNodeAlways` (append to the last span of the walk unconditionally).
- [ ] T035 Commit everything, push `spec/ellipsis-folded-block-115`, and open the PR against `master` with the body from T033/T034. Then requeue the pool review with `/Users/arrrrny/Developer/forklift/tool/requeue_review.dart`. **Do not merge** — the pool merges.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup — BLOCKS all stories.
- **US1 (Phase 3)**: depends on Foundational. This is the MVP.
- **US2 (Phase 4)**: depends on US1's marker rendering being in place.
- **US3 (Phase 5)**: depends on Foundational; independent of US1/US2 delivery order.
- **Polish (Phase 6)**: depends on all desired stories being complete.

### Story Dependencies

- **US1 (P1)**: starts after Foundational. No dependency on other stories.
- **US2 (P1)**: needs the marker rendering from US1 to assert against.
- **US3 (P2)**: needs the style fallback from Foundational.

### Within Each Story

Tests first, RED, then implementation, then GREEN — per the repo's TDD profile.

### Parallel Opportunities

- T002, T003 and T004 run alongside T005's and T006's authoring.
- Within a story, the tests marked [P] are independent behaviours and can be
  written in one pass, then run RED together.
- T033 (CHANGELOG) can be written while the coverage gate runs.

---

## Parallel Example: User Story 2

```bash
# Write T016–T020, run RED together:
flutter test --concurrency=2 test/src/code_field/fold_ellipsis_test.dart
# No implementation change is expected for this story; a RED here is a defect in
# the splice, not a test to adjust.
```

## Implementation Strategy

### MVP First (US1 only)

1. Phase 1: Setup — including T002, proving the folding and span-tree nets are
   intact.
2. Phase 2: Foundational — the derivation, the terminating-node splice, the
   final-line splice.
3. Phase 3: US1 — the marker in the right place in every fold shape.
4. **STOP and VALIDATE**: T012 and T013 must fail before T008/T009 and pass
   after. A marker that only appears in the shared-row shape means the
   terminating-node rule and the final-line splice are both missing.
5. Only then continue to US2/US3.

### Why the own-row-closer test is the load-bearing one

`quickstart.md` §6 lists what must fail for a broken implementation. The single
most plausible wrong implementation is appending the marker to whatever node the
walk happens to be at when it notices a fold — or to the last node of the whole
walk. It passes the `parsers: [` fixture by luck, because there the kept line is
followed by the closer's row and the last node of the walk is elsewhere. T012 is
the test that catches it: in the `}void main(){` shape the closer has a row of
its own (`code.dart:670-708`), so a marker on the closer's row is unambiguously
wrong. T013 is its twin — it catches the same mistake from the other end, by
making the kept line the last line in the tree.

---

## Notes

- `--concurrency=2` on every `flutter test`; `-j 2` for `dart test`. Never raise
  it on this host.
- `flutter test` hides failures — grep `EXCEPTION CAUGHT` / `Expected:` /
  `Actual:` if something looks off.
- Only one PR open at a time; the pool merges, not us.
- The three regression files from T002 must pass unmodified. A RED there is a
  defect in this change, not stale tests.
- `span_builder_test.dart` asserts whole trees. Adding an example there means
  writing the expected tree out in full — including the marker as a child of the
  terminating node — and running it. Do not weaken an existing example to make
  room.
