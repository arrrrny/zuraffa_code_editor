# Tasks: highlight-cursor-line

**Input**: Design documents from `.specify/specs/highlight-cursor-line-113/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/current-line-highlight.md, quickstart.md

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

**Purpose**: confirm the working state, and prove #86 is intact before anything
is touched.

- [ ] T001 In `/Users/arrrrny/Developer/zuraffa_113`, confirm `git log --oneline -1` is the plan commit and the tree is clean, then `flutter pub get`.
- [ ] T002 Run `flutter test --concurrency=2 test/src/code_field/per_line_background_test.dart` and confirm all eleven tests pass **unmodified**. This is the regression net; if one fails now, stop and investigate before writing anything — it means the rebase onto #87's merge broke something.
- [ ] T003 [P] Read `lib/src/code_field/line_background.dart`, `lib/src/code_field/code_field.dart:620-700` (the layer gate and `_visibleRowHeights`), `lib/src/code/code_lines.dart:1-70` (`characterIndexToLineIndex`), and `test/src/code_field/per_line_background_test.dart` end to end, as the widget-test and fixture patterns to mirror.
- [ ] T004 Record the exact byte-size / line count of the eleven existing tests, and the current `EXEMPT_LINES` contents of `tool/coverage_gate.py`, so the RED run and the coverage run can be told apart from drift later.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the field, the caret-line resolution and the composition. No story
can be delivered without these.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

### Tests (write first, must fail)

- [ ] T005 [P] Create `test/src/code_field/current_line_highlight_test.dart` with the fixtures from `per_line_background_test.dart` (the `_shortFirstLine` document, `createApp`, `createController`) and one test: a `CodeField` with `currentLineColor` set and no `lineBackgroundBuilder` tints the caret's row. Run `flutter test --concurrency=2 test/src/code_field/current_line_highlight_test.dart` — RED, because `currentLineColor` does not exist yet.

### Implementation

- [ ] T006 Add `final Color? currentLineColor;` to `CodeController` in `lib/src/code_field/code_controller.dart`, directly beside `lineBackgroundBuilder`, with the doc comment from `contracts/current-line-highlight.md` §The field. It is a plain field read during render, so nothing is passed into `_createTextSpan` and no listener is added.
- [ ] T007 In `lib/src/code_field/line_background.dart`, compute `currentLineIndex` once in `build`, behind the guard from `research.md` R4 (`extentOffset >= 0 && extentOffset <= controller.code.text.length`, else `-1`), and change the colour resolution at line 55 from `builder(visibleLines[row])` to the `??` chain from the contract. Nothing else in the layer changes.
- [ ] T008 Widen the layer's gate at `lib/src/code_field/code_field.dart:652-653` to `lineBackgroundBuilder == null && currentLineColor == null`. No new `Stack`, no new scroll controller, no change to `_visibleRowHeights`.

**Checkpoint**: the field exists, the default tree is unchanged, and a caret is tinted.

---

## Phase 3: User Story 1 - The caret's row is tinted, across the whole row (Priority: P1) 🎯 MVP

**Goal**: a host that sets only `currentLineColor` sees VSCode's
`renderLineHighlight: all`.

**Independent Test**: pump a `CodeField` with `currentLineColor` set and the caret
on line 2; the tinted row's width equals the editor's width and is strictly
greater than line 2's own text width.

### Tests (write first, must fail)

- [ ] T009 [P] [US1] Add a test that tints via `currentLineColor` alone, with the caret moved onto a one-character line, and asserts via `tester.getSize(...)` that the tinted row's width equals the editor's width and exceeds the text's own measured extent. RED.
- [ ] T010 [P] [US1] Add a test that `currentLineColor` alone leaves the other rows untilted (`SizedBox`, not a transparent `Container`) — the tint box helper from `per_line_background_test.dart` reused. RED.

### Implementation

- [ ] T011 [US1] No implementation change: T006–T008 make T009 and T010 GREEN. If T010 is RED with a transparent container appearing, the layer is emitting a `Container` with a null colour — check `line_background.dart:57-59` still returns `SizedBox` on `null`.
- [ ] T012 [US1] Run `flutter test --concurrency=2 test/src/code_field/current_line_highlight_test.dart` — GREEN. Then re-run `per_line_background_test.dart` and confirm it is still all green.

**Checkpoint**: US1 is fully functional and independently testable. This is the MVP.

---

## Phase 4: User Story 2 - The tint follows the caret (Priority: P1)

**Goal**: the highlight tracks the caret through every way a caret moves, and
survives every caret state.

**Independent Test**: place the caret on line 0, then move it by keystroke, by
tap, and by shift-arrow; the tint is on the caret's line each time, including
when the selection spans several lines.

### Tests (write first, must fail)

- [ ] T013 [P] [US2] Add a test that moves the caret by typing into the field and asserts the tint moved to the new line. RED (or GREEN if T006–T008 already deliver it — if RED, the rebuild path from `research.md` R2 is wrong and a listener is needed; do not paper over it).
- [ ] T014 [P] [US2] Add a test that taps on a line and asserts the tint follows. RED.
- [ ] T015 [P] [US2] Add a test that creates a selection spanning lines 2–5 with shift-arrow (or `controller.selection = const TextSelection(baseOffset: …, extentOffset: …)` plus `notifyListeners`) and asserts **only the extent's line** is tinted. RED — this is the test that catches `selection.baseOffset`.
- [ ] T016 [P] [US2] Add a test with an empty document and no interaction (`extentOffset == -1`): no tint, no exception. RED — catches a missing guard.
- [ ] T017 [P] [US2] Add a test with the caret at the very end of the text (`extentOffset == text.length`): the last line is tinted. RED — catches a guard that rejects the documented end-of-text index.
- [ ] T018 [P] [US2] Add a test that places the caret inside a foldable block, folds it, and asserts nothing is tinted and no exception is thrown. RED.

### Implementation

- [ ] T019 [US2] If T013 is RED, add a listener in `CodeField.initState` (`code_field.dart:362` region) and remove it in `dispose`. Only if a test proves it is required — `research.md` R2 argues `_onTextChanged` already covers it, and an unnecessary listener is a permanent tax on every keystroke.
- [ ] T020 [US2] Run the whole file `flutter test --concurrency=2 test/src/code_field/current_line_highlight_test.dart` — GREEN. Re-run `per_line_background_test.dart`.

**Checkpoint**: US1 and US2 both work independently.

---

## Phase 5: User Story 3 - Composition and the opt-in (Priority: P3)

**Goal**: the two hooks compose with the host builder winning, the default tree
is untouched, and the wrong doc example is corrected.

**Independent Test**: with both hooks set, the host builder's colour wins on the
lines it colours while `currentLineColor` still tints the caret's line; with both
hooks null, the tree has no `Stack` and no layer.

### Tests (write first, must fail)

- [ ] T021 [P] [US3] Add a test that sets both hooks: the builder tints line 3, the caret is on line 1, and both tints are present on their own lines. RED.
- [ ] T022 [P] [US3] Add a test where the builder tints the caret's line too: the builder's colour wins on that line, and `currentLineColor` tints no other line. RED — catches a `??` chain written the wrong way round.
- [ ] T023 [P] [US3] Add a test that a field with neither hook set has no `Stack` and no `LineBackgroundLayer` under it, mirroring `per_line_background_test.dart:82-101`. RED if the gate is widened disjunctively.
- [ ] T024 [P] [US3] Add a test with a `CodeController` with no language set and `currentLineColor` set — the caret's line is still tinted. RED if the tint was routed through the span tree.
- [ ] T025 [P] [US3] Add a test that reassigns `currentLineColor` on a live controller, calls `notifyListeners()`, and pumps — the tint changes without reconstructing the controller. RED if the field is only read once.

### Implementation

- [ ] T026 [US3] Correct the doc example at `lib/src/code_field/code_controller.dart:169-170` — the `line == controller.selection.base.offset` category error — to the text in `contracts/current-line-highlight.md` §The doc example to correct. Verify by reading the surrounding doc comment so the prose matches what the field now does.
- [ ] T027 [US3] Confirm T021–T025 GREEN with no further implementation change; any RED here means the composition is inverted or the field is cached, not that a test needs adjusting.

**Checkpoint**: all stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: the gates this repo enforces, and the PR.

- [ ] T028 Run the CI-identical coverage gate from `quickstart.md` §3. Must read `Coverage gate: 100.00% >= 100.00% — OK`. If the known host flake (`quickstart.md` §6) reds, re-run that file alone and record it in the PR body; do not widen its bound.
- [ ] T029 If any new branch is unreachable, prove it dead and add it to `EXEMPT_LINES` in `tool/coverage_gate.py` **with a written reason**, renumbering by line number — the tool pins by line, so any insertion above an exempted line shifts it. Check the count against T004's record first.
- [ ] T030 `dart analyze --fatal-infos` and `dart format --output=none --set-exit-if-changed .` both silent.
- [ ] T031 [P] Add a CHANGELOG.md entry for the new field, above the existing entries.
- [ ] T032 Write `tdd/verification.md`: the RED evidence per test, the naming of the mutants and their kill status, and the coverage-gate number. Mutation candidates for this spec, all of which must be killed: `M-useBaseOffset` (extent→base), `M-dropGuard` (remove the range check), `M-invertChain` (swap the `??` order), `M-hardcodeZero` (caret line always 0), `M-disjunctiveGate` (`||` instead of `&&`).
- [ ] T033 Commit everything, push `spec/highlight-cursor-line-113`, and open the PR against `master` with the body from T031/T032. Then requeue the pool review with `/Users/arrrrny/Developer/forklift/tool/requeue_review.dart`. **Do not merge** — the pool merges.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup — BLOCKS all stories.
- **US1 (Phase 3)**: depends on Foundational. This is the MVP.
- **US2 (Phase 4)**: depends on US1's tint rendering being in place.
- **US3 (Phase 5)**: depends on Foundational; independent of US1/US2 delivery order.
- **Polish (Phase 6)**: depends on all desired stories being complete.

### Story Dependencies

- **US1 (P1)**: starts after Foundational. No dependency on other stories.
- **US2 (P1)**: needs the tint rendering from US1 to assert against.
- **US3 (P3)**: needs the composition from Foundational.

### Within Each Story

Tests first, RED, then implementation, then GREEN — per the repo's TDD profile.

### Parallel Opportunities

- T002, T003 and T004 run alongside T005's authoring.
- Within a story, the tests marked [P] are independent behaviours and can be
  written in one pass, then run RED together.
- T031 (CHANGELOG) can be written while the coverage gate runs.

---

## Parallel Example: User Story 2

```bash
# Write T013–T018, run RED together:
flutter test --concurrency=2 test/src/code_field/current_line_highlight_test.dart
# Then implement T019 only if T013 proved it necessary, and re-run until GREEN.
```

## Implementation Strategy

### MVP First (US1 only)

1. Phase 1: Setup — including T002, proving #86 is intact.
2. Phase 2: Foundational — the field, the guard, the composition, the gate.
3. Phase 3: US1 — the caret's row is tinted across the whole row.
4. **STOP and VALIDATE**: T009's width assertion must fail before T007 and pass
   after. A tint that only covers the caret's glyph run means T009 is not
   actually asserting width.
5. Only then continue to US2/US3.

### Why the `extent` test is the load-bearing one

`quickstart.md` §5 lists what must fail for a broken implementation. The single
most plausible wrong implementation is `selection.baseOffset` — it looks
equivalent, it is what the **wrong doc example** used, and it passes every
collapsed-caret test. T015 is the test that catches it, which is why the doc
example has to be corrected in the same change: leaving it wrong invites the
next implementer to make exactly this mistake.

---

## Notes

- `--concurrency=2` on every `flutter test`; `-j 2` for `dart test`. Never raise
  it on this host.
- `flutter test` hides failures — grep `EXCEPTION CAUGHT` / `Expected:` /
  `Actual:` if something looks off.
- Only one PR open at a time; the pool merges, not us.
- The eleven `per_line_background_test.dart` tests are the regression net and
  must pass unmodified. A RED there is a defect in this change, not stale tests.
