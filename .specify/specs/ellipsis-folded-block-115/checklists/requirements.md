# Requirements checklist: ellipsis-folded-block

Every acceptance criterion from `spec.md`, with the task that delivers it and the
test that proves it. Nothing is marked complete until its test has been seen RED
and then GREEN.

## Functional

- [ ] **FR-001** A folded block's kept line ends with `' …'` after its last visible character. — T005, T006, T011
- [ ] **FR-002** With nothing folded, the span tree is byte-for-byte what it is today. — T005 (`shows no ellipsis when nothing is folded`), T002 (the three existing examples, unmodified)
- [ ] **FR-003** `controller.text` is byte-for-byte identical before a fold, after a fold, and after unfolding. — T016
- [ ] **FR-004** Unfolding removes the marker. — T017
- [ ] **FR-005** The marker survives a re-parse after a keystroke on the kept line. — T018
- [ ] **FR-006** The marker lands after the closer when the closer shares the kept row. — T011
- [ ] **FR-007** No marker on the closer's own row when the closer has a row of its own. — T012
- [ ] **FR-008** A kept line that is the last visible line with no trailing newline still gets the marker. — T013
- [ ] **FR-009** Exactly one marker per kept line; a nested fold swallowed by an outer one contributes nothing. — T019
- [ ] **FR-010** Nested and adjacent folds each get their own marker. — T020
- [ ] **FR-011** The marker carries the base style, not the token style. — T023, T024
- [ ] **FR-012** The marker survives the search-match build path. — T025
- [ ] **FR-013** No new public API: no constructor parameter, no `CodeController` field, no new export. — T007–T009, review

## Robustness (each one is a coverage-gate branch and a crash or a wrong render if wrong)

- [ ] **RB-001** A kept line with no trailing newline is handled by the second splice, not by falling through. — T013
- [ ] **RB-002** `cutLineIndexIfVisible` returning null — a block nested inside an already-folded one — discards that block rather than crashing or double-marking. — T019
- [ ] **RB-003** The marker never enters `visibleText` or `value.text`, so no offset moves and no selection breaks. — T016
- [ ] **RB-004** A null `rootStyle` still renders a marker. — T024
- [ ] **RB-005** The no-language and IME-composition paths render exactly as they do today. — T026, T027

## Non-regression

- [ ] **NR-001** The three examples in `test/src/code_field/span_builder_test.dart` pass unmodified. — T002 before, T010/T015/T022 after
- [ ] **NR-002** `test/src/folding/folded_closing_line_test.dart` passes unmodified — the folded text it pins is exactly what the marker annotates. — T002 before, T010 after
- [ ] **NR-003** `test/src/folding/folded_block_keeps_next_block_start_test.dart` passes unmodified — it owns the own-row-closer and swallowed-nested-fold shapes. — T002 before, T015 after
- [ ] **NR-004** `test/src/code_field/search_result_highlighted_builder_null_style_test.dart` passes unmodified — it owns the null-style search path. — T030
- [ ] **NR-005** `CodeField`'s widget tree is unchanged: no new widget, no new gate, no new `Stack`. — T025, review

## Documentation

- [ ] **DOC-001** The marker's private constant and its derivation are documented in `span_builder.dart`, including why the marker is painted and never typed. — T007, T008
- [ ] **DOC-002** The IME-composition and no-language bypasses are stated in the doc comment rather than left implicit. — T026, T027
- [ ] **DOC-003** CHANGELOG entry added for the marker. — T033

## Gates

- [ ] **GT-001** `flutter test --concurrency=2` — full suite green (modulo the documented host flake, re-run alone). — T030
- [ ] **GT-002** `python3 tool/coverage_gate.py --min 100` reads `100.00% >= 100.00% — OK`. — T030
- [ ] **GT-003** `dart analyze --fatal-infos` silent. — T032
- [ ] **GT-004** `dart format --output=none --set-exit-if-changed .` silent. — T032
- [ ] **GT-005** CHANGELOG entry added. — T033

## TDD discipline

- [ ] **TDD-001** Every test above was written and observed RED before its implementation task. — recorded in `tdd/verification.md`
- [ ] **TDD-002** All seven mutation candidates from T034 were applied and killed: `M-noSplice`, `M-midLine`, `M-lineZero`, `M-keepAfterUnfold`, `M-tokenStyle`, `M-keepNulls`, `M-lastNodeAlways`.
- [ ] **TDD-003** No test was weakened, skipped or narrowed to make the gate pass, and no existing example in `span_builder_test.dart` was edited.

## Scope discipline

- [ ] **SC-001** No configurability was added — no glyph, colour, size, prefix, suffix or position parameter, and no `CodeController` field. — review
- [ ] **SC-002** The gutter chevron is unchanged, and no fourth gutter column was added. — review
- [ ] **SC-003** The folding machinery — `foldableBlockToHiddenRange`, `cutString`, `cutSelection`, `recoverSelection`, `getEditResult`, the line-numbering breakpoints — is untouched. — T002, T016, review
- [ ] **SC-004** No new public type and no new export; the marker constant is private to `span_builder.dart`. — review
- [ ] **SC-005** No overlay layer, no `Stack`, no new scroll controller, no new listener. — review

## Definition of done

All boxes above checked, the coverage gate reading 100.00%, the branch pushed and
the PR open with the pool requeued. **Merging is the pool's job, never ours.**
