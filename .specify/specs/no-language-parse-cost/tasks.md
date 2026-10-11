# Tasks: pin the cost of the keystroke path when no language is selected

**Input**: Design documents from `.specify/specs/no-language-parse-cost/`

**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: Required by the feature — the measurement pin *is* the deliverable (FR-004, FR-005, SC-001–SC-004). There is no implementation work.

**Organization**: This is a decision feature. The spec's finding is that the reported ~20 s stall is
not reproducible on this fork, so the tasks are: write the test that pins the measurement, prove it can
fail, record the decision on the issue. No `lib/` change.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

No project scaffolding is needed — the repository, test tree, CI and coverage gate all exist.

- [x] T001 Confirm `flutter pub get` resolves and `flutter test` is green on `master` (baseline)
- [x] T002 Confirm the branch is `spec/no-language-parse-cost` at `master`

---

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T003 Pin `.specify/feature.json` to `.specify/specs/no-language-parse-cost` (spec-whole Step 0)
- [x] T004 Verify the language-fallback mechanism in the installed dependency rather than trusting the issue:
      `highlight-0.7.0/lib/src/highlight.dart:271` (`_getLanguage(language) ?? plaintext`) and
      `highlight-0.7.0/lib/languages/plaintext.dart:6` (`Mode(refs: {}, disableAutodetect: true)`)

---

## Phase 3: User Story 1 - Typing in a large document with no language selected stays responsive (Priority: P1) 🎯 MVP

**Goal**: the reported symptom is answered with a number.

**Independent Test**: one keystroke driven through a `CodeController` with no language on a 4800-line
document, compared against the same document with `java`.

### Tests for User Story 1

- [ ] T005 [US1] Write `test/src/code_field/no_language_keystroke_test.dart`:
      a 4800-line Java-like document fixture matching `test/src/code_field/edit_latency_test.dart:31`,
      a no-language controller built directly (`CodeController` with no `setLanguage` call — do **not**
      change the shared `createController` default, see `research.md` Decision 4), a median-of-5
      keystroke measurement, and the printed breakdown of parse cost for both paths.
- [ ] T006 [US1] Assert SC-002: no-language keystroke median < 100 ms (one tenth of a second).
- [ ] T007 [US1] Assert SC-003: no-language keystroke median ≤ with-language keystroke median.
- [ ] T008 [US1] Assert the unresolvable-alias edge case: a controller whose language is an unregistered
      `Mode` costs the same as no language (FR-003).
- [ ] T009 [US1] Run the file and record the measured numbers; they must match the spec's quoted
      3.0 ms / 318.2 ms parse costs to within JIT noise.

---

## Phase 4: User Story 2 - The cheap path cannot silently regress (Priority: P2)

**Goal**: the measurement is worth taking once because it is now pinned.

**Independent Test**: the same file, whose assertions fail if the no-language parse becomes expensive.

### Tests for User Story 2

- [ ] T010 [US2] Assert SC-001: no-language `highlight.parse` cost < 5% of the with-language
      `highlight.parse` cost on the same document (FR-004).
- [ ] T011 [US2] Assert SC-004 (the tripwire): the ratio no-language-keystroke / with-language-keystroke
      is bounded, so a change that makes the no-language parse comparable to the with-language parse
      reddens the suite. Bound derived from the measured evidence, not from a round number.
- [ ] T012 [US2] Prove the tripwire can fail: fault-inject a no-language path that does token work
      (e.g. register a real language under the empty name in the test process) and confirm the
      assertions redden; then remove the injection. Record both outcomes in the test's doc comment,
      following `test/src/code_field/edit_latency_test.dart:126-141`.

---

## Phase 5: User Story 3 - The decision is recorded with its evidence (Priority: P3)

**Goal**: a reader of the issue learns what was measured and why no code changed.

**Independent Test**: the spec, plus a comment on the issue.

### Implementation for User Story 3

- [ ] T013 [US3] Post a comment on `arrrrny/zuraffa_code_editor#111` carrying the measured numbers,
      the mechanism (`highlight` 0.7.0's `plaintext` fallback), and the conclusion that no code change
      is warranted (FR-006).
- [ ] T014 [US3] Update the spec's Status from Draft to reflect the recorded decision, and note the
      test file as the pin.
- [ ] T015 [US3] Run the coverage gate to confirm the new test cannot lower the 100% number
      (`tool/coverage_gate.py --min 100`).

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T016 [P] `dart format` the new test; `dart analyze --fatal-infos` the package.
- [ ] T017 Run the full suite and record the test count.
- [ ] T018 Decide whether to open a PR: **only if the audit demands a code change.** The deliverable is
      a test that pins a decision, which belongs on `master` via the pool like any other change.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup / Foundational**: no dependencies — both already complete
- **US1 (Phase 3)**: depends on T004 (the verified mechanism) only
- **US2 (Phase 4)**: depends on T005–T009 (the measurement must exist before it can be bounded)
- **US3 (Phase 5)**: depends on US1 + US2 (the numbers must be final before they are posted)
- **Polish**: depends on all

### User Story Dependencies

- **US1 (P1)**: independent — the whole symptom
- **US2 (P2)**: shares the file with US1, so it runs after it rather than in parallel
- **US3 (P3)**: independent of the code, dependent on the numbers

### Within Each User Story

- Tests are written first, but they are **green on the unfixed tree** — that is the finding, not a
  process violation. The TDD loop's output here is the recorded evidence that the behaviour already
  holds, plus the fault injection in T012 proving the assertions are not vacuous.

---

## Notes

- No `[P]` parallelism: one new file, one author.
- Do not add a `language ?? java` change to `test/src/common/create_app.dart`.
- Do not commit `test/coverage_helper_test.dart` or `coverage/`.
- The pre-commit scratch probes (`test/tmp_probe_111_test.dart`, `test/tmp_probe_111b_test.dart`) were
  deleted before this file was written; keep it that way.
