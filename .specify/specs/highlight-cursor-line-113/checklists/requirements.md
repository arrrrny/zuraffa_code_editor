# Requirements checklist: highlight-cursor-line

Every acceptance criterion from `spec.md`, with the task that delivers it and the
test that proves it. Nothing is marked complete until its test has been seen RED
and then GREEN.

## Functional

- [ ] **FR-001** `CodeController` accepts `currentLineColor`, `Color?`, default null. — T006
- [ ] **FR-002** With it set and `lineBackgroundBuilder` null, the caret's row is tinted with it, across the full row width, behind the text. — T009
- [ ] **FR-003** Other rows are untilted when only `currentLineColor` is set. — T010
- [ ] **FR-004** The tint follows the caret by keystroke. — T013
- [ ] **FR-005** The tint follows the caret by tap. — T014
- [ ] **FR-006** A selection spanning several lines tints only the caret's (`extent`) line. — T015
- [ ] **FR-007** A caret inside a folded block tints nothing, without crashing. — T018
- [ ] **FR-008** Both hooks set: the host builder's colour wins where it colours, and `currentLineColor` tints the caret's line where the builder returns null. — T021, T022
- [ ] **FR-009** A field with neither hook set renders the same widget tree as before this change. — T023

## Robustness (each one is a coverage-gate branch and a crash if wrong)

- [ ] **RB-001** An empty document with no selection (`extentOffset == -1`) renders and tints nothing. — T016
- [ ] **RB-002** A caret at the very end of the text (`extentOffset == text.length`) tints the last line. — T017
- [ ] **RB-003** `characterIndexToLineIndex` can never throw inside `build`, because every call is inside its documented `[0, text.length]` domain. — T016, T017, plus the guard in T007
- [ ] **RB-004** A caret on a line hidden by a collapsed section tints nothing. — T018

## Non-regression

- [ ] **NR-001** The eleven tests in `test/src/code_field/per_line_background_test.dart` pass unmodified. — T002 before, T012/T020 after
- [ ] **NR-002** A field with no language set still tints the caret's line. — T024
- [ ] **NR-003** Reassigning `currentLineColor` at runtime re-renders. — T025

## Documentation

- [ ] **DOC-001** The wrong doc example at `code_controller.dart:169-170` (line index compared against a character offset) is corrected. — T026
- [ ] **DOC-002** `currentLineColor`'s doc comment states what it tints, which offset defines the caret, and how it composes with `lineBackgroundBuilder`. — T006

## Gates

- [ ] **GT-001** `flutter test --concurrency=2` — full suite green (modulo the documented host flake, re-run alone). — T028
- [ ] **GT-002** `python3 tool/coverage_gate.py --min 100` reads `100.00% >= 100.00% — OK`. — T028
- [ ] **GT-003** `dart analyze --fatal-infos` silent. — T030
- [ ] **GT-004** `dart format --output=none --set-exit-if-changed .` silent. — T030
- [ ] **GT-005** CHANGELOG entry added. — T031

## TDD discipline

- [ ] **TDD-001** Every test above was written and observed RED before its implementation task. — recorded in `tdd/verification.md`
- [ ] **TDD-002** All five mutation candidates from T032 were applied and killed: `M-useBaseOffset`, `M-dropGuard`, `M-invertChain`, `M-hardcodeZero`, `M-disjunctiveGate`.
- [ ] **TDD-003** No test was weakened, skipped or narrowed to make the gate pass.

## Scope discipline

- [ ] **SC-001** No gutter / line-number tint was added (explicitly out of scope). — review
- [ ] **SC-002** `lineBackgroundBuilder`'s signature, call order and coordinate space are unchanged. — review
- [ ] **SC-003** No new public type and no new export; `LineBackgroundLayer` stays `@internal`. — review
- [ ] **SC-004** No listener was added unless a RED test proved one necessary. — T019

## Definition of done

All boxes above checked, the coverage gate reading 100.00%, the branch pushed and
the PR open with the pool requeued. **Merging is the pool's job, never ours.**
