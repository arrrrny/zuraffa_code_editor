# Tasks: per-line-background

**Input**: Design documents from `.specify/specs/per-line-background-86/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/code-controller-hook.md, quickstart.md

**Tests**: TDD is mandatory for this feature (the repo's TDD profile is raw
`flutter test`; the coverage gate is 100%). Every story below therefore has its
tests written and run RED before its implementation tasks.

**Organization**: Tasks are grouped by user story so each is independently
testable. The spec has no separate "user stories" section — the stories below are
derived from its acceptance criteria.

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

Single Flutter package. Paths are repository-root relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: confirm the working state and learn the two harnesses the tests will
sit next to.

- [ ] T001 In `/Users/arrrrny/Developer/zuraffa_86`, confirm `git log --oneline -1` is the plan commit and the tree is clean, then `flutter pub get`.
- [ ] T002 [P] Read `lib/src/code_field/code_field.dart`, `lib/src/code_field/code_controller.dart`, `lib/src/code_field/span_builder.dart` end to end, and `test/src/code_field/code_field_decoration_test.dart` + `test/src/gutter/gutter_alignment_harness.dart` as the widget-test and row-height patterns to mirror.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the hook field, the authoritative full line index, and the
null-guarded background layer. No story can be delivered without these.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

### Tests (write first, must fail)

- [ ] T003 [P] Create `test/src/code_field/per_line_background_test.dart` with one test: a `CodeField` with no builder set renders the same `TextSpan` tree as `controller.buildTextSpan` produced before the change. Run `flutter test --concurrency=2 test/src/code_field/per_line_background_test.dart` — RED because `lineBackgroundBuilder` does not exist yet.

### Implementation

- [ ] T004 Add `final Color? Function(int lineIndex)? lineBackgroundBuilder;` with the doc comment from `contracts/code-controller-hook.md` to `CodeController` in `lib/src/code_field/code_controller.dart`, defaulting to null, and pass it into the `SpanBuilder(...)` construction inside `_createTextSpan` (`code_controller.dart:1287`).
- [ ] T005 In `lib/src/code_field/span_builder.dart`, resolve the **authoritative full line index** for each rendered span: keep `_visibleLineIndex` as the accumulator, but stop using it directly as the span's line — map it through `code.hiddenLineRanges.recoverLineIndex(...)`, and do not let `_updateLineIndex`'s clamp (`span_builder.dart:71`) or a node's internal newlines mis-attribute a span that starts mid-node. Expose the resolved index to `CodeField` (e.g. a `Map<int, int>` or a callback on `SpanBuilder`) so the background layer and the span path agree by construction.
- [ ] T006 [P] Create `lib/src/code_field/line_background.dart`: a private widget taking `CodeController`, the resolved per-line colours, and the row heights, rendering one tinted row per **visible** logical line by iterating `codeController.code.hiddenLineRanges.visibleLineNumbers` in the same order `GutterWidget._fillLineNumbers` does (`gutter.dart:190`). Do not export it.
- [ ] T007 Wire the layer into `CodeField.build()` (`code_field.dart:539`): wrap the `codeField` `TextField` in a `Stack` with `_LineBackgrounds` behind it, **only when `widget.controller.lineBackgroundBuilder != null`**, so the default tree is untouched. Give the layer a `SingleChildScrollView` bound to a third member of the existing `LinkedScrollControllerGroup` (`code_field.dart:355-357`) and row heights from `_wrappedRowHeights(textStyle)` (`code_field.dart:722`, null in non-wrap mode → one line height per row).

**Checkpoint**: the hook exists, the default tree is unchanged, and a set builder tints something. Geometry and edge cases are not yet pinned.

---

## Phase 3: User Story 1 - A host tints a line's whole row (Priority: P1) 🎯 MVP

**Goal**: supplying a colour for line *n* tints that line's entire row, edge to
edge, including the stretch past its last character.

**Independent Test**: pump a `CodeField` whose builder tints line 0, then read
the real layout: the tinted row's width equals the editor's width and is strictly
greater than the width of line 0's own text.

### Tests (write first, must fail)

- [ ] T008 [P] [US1] Add to `test/src/code_field/per_line_background_test.dart` a test that tints line 0 of a document whose line 0 is one character long, and asserts via `tester.getSize(...)` that the tinted row's width equals `tester.getSize(find.byKey(_editorKey-equivalent)).width` and exceeds the text's own measured extent. RED on the current implementation: a `TextStyle.backgroundColor` tint is glyph-width, not row-width.
- [ ] T009 [P] [US1] Add a test that a line the builder returns `null` for has no tinted row, and a document with no tinted line renders exactly the same widget tree as one with no builder. RED.

### Implementation

- [ ] T010 [US1] Make the tint cover the row: in `lib/src/code_field/line_background.dart`, render each visible line as a full-width tinted box whose height is `rowHeights?[i] ?? singleLineHeight`, so a one-character line is still tinted across the whole row. Verify T008 passes.
- [ ] T011 [US1] Confirm the tint sits **behind** the text: assert in T008's test that the tinted row is painted behind the `TextField` (Stack order), so the caret and text remain fully visible and hit-testable on a tinted line.
- [ ] T012 [US1] Run `flutter test --concurrency=2 test/src/code_field/per_line_background_test.dart` — GREEN.

**Checkpoint**: US1 is fully functional and independently testable. This is the MVP.

---

## Phase 4: User Story 2 - The index is the code's own line number (Priority: P2)

**Goal**: the index handed to the builder is the line's 0-based index in the
full, unfolded buffer, correct under folds, hidden sections, multi-line highlight
nodes and a trailing newline.

**Independent Test**: tint one line by full index, then open a fold above it,
rename a hidden section, and place a block comment over it — the tint stays on
that line, and a line inside the fold is not tinted at all.

### Tests (write first, must fail)

- [ ] T013 [P] [US2] Add a test: tint line by full index with a folded block above it — the tint is on the line with that full index, not on the visible row that happens to sit there. RED (an unmapped `_visibleLineIndex` tints the wrong row).
- [ ] T014 [P] [US2] Add a test: a line inside a folded block gets no tinted row and the builder is never called for it (count invocations). RED.
- [ ] T015 [P] [US2] Add a test: a multi-line highlight node (a block comment or a triple-quoted string spanning three lines, in a language whose highlight mode the package already supports) does not leak its tint onto the lines it merely passes through — only the line whose own index produced the colour is tinted. RED on a node-scoped implementation.
- [ ] T016 [P] [US2] Add a test: a document ending in a newline (so the last line is empty) still tinted correctly, with no crash and no off-by-one. RED.
- [ ] T017 [P] [US2] Add a test: a hidden (`visibleSectionNames`/`readOnlySectionNames`) section's lines are not tinted and the builder is not called for them. RED.

### Implementation

- [ ] T018 [US2] Fix attribution per line rather than per node in `lib/src/code_field/span_builder.dart`: a node's own newlines must not re-attribute its children; each rendered span must carry the full index of the line its text starts on. Verify T013–T017 go GREEN one at a time.

**Checkpoint**: US1 and US2 both work independently.

---

## Phase 5: User Story 3 - A pure opt-in (Priority: P3)

**Goal**: the default path is byte-for-byte unchanged, the no-language path
works, the hook is mutable at runtime, and search highlighting still wins.

**Independent Test**: with no builder, the widget tree and span tree are
identical to master; with a builder, an active search match keeps its own
background while the rest of the tinted row keeps the line tint.

### Tests (write first, must fail)

- [ ] T019 [P] [US3] Add a test comparing the `TextSpan` tree of `controller.buildTextSpan(...)` with and without a builder that returns `null` for every line — identical. RED.
- [ ] T020 [P] [US3] Add a test comparing the pumped widget tree with the builder absent against a control pump on master's behaviour (same widget, no `Stack`) — no extra widget is built. RED.
- [ ] T021 [P] [US3] Add a test with `CodeController(text: ..., language: null)` and a builder set — the line is tinted. RED (the no-language path is a single span today).
- [ ] T022 [P] [US3] Add a test with a line tint and an active search match on that line: the matched run keeps the search colour, the rest of the row keeps the line tint. RED.
- [ ] T023 [P] [US3] Add a test that reassigns `controller.lineBackgroundBuilder` on a live controller, calls `notifyListeners()`, and pumps — the tint changes without reconstructing the controller. RED.

### Implementation

- [ ] T024 [US3] In `lib/src/code_field/code_controller.dart`, split `_createTextSpan`'s no-language branch into per-line spans **only when `lineBackgroundBuilder != null`**, leaving the single-span return byte-identical otherwise. Verify T021 GREEN.
- [ ] T025 [US3] Confirm search layering: `SearchResultHighlightedBuilder` (`search_result_highlighted_builder.dart`) runs after this hook and re-wraps matched runs with its own `backgroundColor`; verify T022 GREEN with no change to that builder.
- [ ] T026 [US3] Verify T023 GREEN — the field is read during `build`, so no new plumbing should be needed; add a listener only if the test proves one is required.

**Checkpoint**: all stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: the gates this repo enforces, and the PR.

- [ ] T027 Run the CI-identical coverage gate from `quickstart.md` §3: helper → `flutter test --coverage --concurrency=2` → `python3 tool/coverage_gate.py --min 100` → remove helper and `coverage/`. Must read `Coverage gate: 100.00% >= 100.00% — OK`.
- [ ] T028 If any new branch is unreachable, prove it dead and add it to `EXEMPT_LINES` in `tool/coverage_gate.py` **with a written reason**, renumbering by line number (the tool pins by line, so any insertion above an exempted line shifts it).
- [ ] T029 `dart analyze --fatal-infos` and `dart format --output=none --set-exit-if-changed .` both silent. If either flags `lib/src/code/code.dart` or `test/src/folding/folded_closing_line_test.dart`, that is pre-existing master drift, not this change.
- [ ] T030 [P] Add a CHANGELOG.md entry for the new field, above the existing `#137` entry.
- [ ] T031 Write the PR body: what the hook is, the measured reason it is a row layer and not `TextStyle.backgroundColor`, the acceptance criteria covered, and the coverage-gate number. Then commit, push `spec/per-line-background-86`, open the PR against `master`, and re-queue the pool review with `/Users/arrrrny/Developer/forklift/tool/requeue_review.dart`.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup — BLOCKS all stories.
- **US1 (Phase 3)**: depends on Foundational. This is the MVP.
- **US2 (Phase 4)**: depends on Foundational and on US1's tint rendering being in place.
- **US3 (Phase 5)**: depends on Foundational; independent of US1/US2 delivery order.
- **Polish (Phase 6)**: depends on all desired stories being complete.

### Story Dependencies

- **US1 (P1)**: starts after Foundational. No dependency on other stories.
- **US2 (P2)**: starts after Foundational; shares `span_builder.dart` with the foundational index work, so it must follow T005.
- **US3 (P3)**: starts after Foundational; its no-language task (T024) touches `code_controller.dart` after T004.

### Within Each Story

Tests first, RED, then implementation, then GREEN — per the repo's TDD profile.

### Parallel Opportunities

- T002 runs alongside T003's authoring.
- Within each story, the tests marked [P] are independent files/behaviours and can be written in one pass; they are run RED together.
- T030 (CHANGELOG) can be written while the coverage gate runs.

---

## Parallel Example: User Story 1

```bash
# Write both US1 tests, run RED together:
flutter test --concurrency=2 test/src/code_field/per_line_background_test.dart
# Then implement T010–T011 and re-run until GREEN.
```

## Implementation Strategy

### MVP First (US1 only)

1. Phase 1: Setup.
2. Phase 2: Foundational — the hook, the index, the null-guarded layer.
3. Phase 3: US1 — the full-row tint.
4. **STOP and VALIDATE**: the geometry test in T008 must fail before T010 and pass after. A tint that only covers the glyph run means T008 is not actually asserting width.
5. Only then continue to US2/US3.

### Why the geometry assertion is the load-bearing one

`quickstart.md` §5 lists what must fail for a broken implementation. The single
most likely wrong implementation — `TextStyle.backgroundColor` on the line's
spans — passes every span-level assertion and renders a highlight that stops at
the last character. T008 is the test that catches it.

---

## Notes

- `--concurrency=2` on every `flutter test`; `-j 2` for `dart test`. Never raise
  it on this host.
- `flutter test` hides failures — grep `EXCEPTION CAUGHT` / `Expected:` /
  `Actual:` if something looks off.
- Only one PR open at a time; the pool merges, not us.
