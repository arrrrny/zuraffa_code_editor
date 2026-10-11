# Feature Specification: pin the cost of the keystroke path when no language is selected

**Feature Branch**: `spec/no-language-parse-cost`

**Created**: 2026-10-11

**Status**: Draft

**Input**: User description: "highlight.parse() still runs with no language set, so an
unhighlighted 4800-line document hangs the same ~20s. Skipping the parse when the
language is null looks like a cheap keystroke-path win."
— fork issue [arrrrny/zuraffa_code_editor#111](https://github.com/arrrrny/zuraffa_code_editor/issues/111),
synced from upstream `akvelon/flutter-code-editor#246`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Typing in a large document with no language selected stays responsive (Priority: P1)

A developer embeds the editor without configuring a language — a scratch pad, a
log viewer, a plain-text editor — and types in a document of thousands of lines.
They expect the editor to behave the same as it does in a small document, minus
the highlighting they never asked for. They do not expect to wait seconds per
keystroke.

**Why this priority**: this is the entire reported symptom. If it holds, the issue
is answered; if it does not, nothing else in this feature matters.

**Independent Test**: measure one keystroke through the controller on a 4800-line
document with no language configured, and compare it to the same document with a
language configured.

**Acceptance Scenarios**:

1. **Given** a 4800-line document and no language selected, **When** the user types
   one character, **Then** the keystroke completes in the tens of milliseconds, not
   seconds.
2. **Given** the same document with a language selected, **When** the user types one
   character, **Then** the no-language path is not slower than the with-language path.

---

### User Story 2 - The cheap path cannot silently regress (Priority: P2)

A future change makes an unrecognised language fall back to language
auto-detection, or otherwise makes the no-language parse expensive. Without a pin,
nothing notices and every unhighlighted editor becomes slow.

**Why this priority**: the measurement is only worth taking once if it is pinned.
This is the deliverable of the feature.

**Independent Test**: a test that measures the parse and the keystroke with no
language selected and asserts both stay within a budget.

**Acceptance Scenarios**:

1. **Given** a large document and no language, **When** the highlight step runs,
   **Then** it costs a small fraction of a with-language parse.
2. **Given** the same conditions, **When** one keystroke is driven through the
   controller, **Then** its cost is dominated by the rest of the update path and not
   by the parse.

---

### User Story 3 - The decision is recorded with its evidence (Priority: P3)

A reader of this spec — including a future maintainer — learns what was measured,
what the answer was, and why no code change was made.

**Why this priority**: an issue closed with "works for me" teaches nobody anything.

**Independent Test**: the spec itself, plus a comment on the issue carrying the
numbers.

**Acceptance Scenarios**:

1. **Given** the issue as filed, **When** this spec is read, **Then** the premise in
   it is answered with a measurement, not an assertion.

### Edge Cases

- A language name that is set but unrecognised (an unregistered alias) — must cost
  the same as no language, since it resolves to the same fallback.
- A single-line document with no language — must not be slower than a large one per
  keystroke by a wide margin attributable to the parse.
- The autocompleter is disabled when no language is set (`autocompleter.mode` is
  null), so its keystroke cost must not be attributed to the parse either.
- The measurement runs on an unoptimized JIT in `flutter test`; absolute numbers are
  machine-dependent, but the *ratio* between the no-language and with-language paths
  is not.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST resolve an absent language to a mode that performs no
  token-level work, so that highlighting an unhighlighted document is not the cost
  driver of a keystroke.
- **FR-002**: A keystroke on a large document with no language selected MUST complete
  without a multi-second stall.
- **FR-003**: A language name that does not resolve MUST be treated exactly like no
  language at all.
- **FR-004**: The measured no-language parse cost MUST be pinned by a test, so a
  change that makes it expensive fails the suite rather than reaching users.
- **FR-005**: The test MUST compare the no-language path against the with-language
  path, because an absolute millisecond budget is machine-dependent and would be a
  flaky gate.
- **FR-006**: The spec MUST record the decision and its evidence, and the issue MUST
  carry the measurement.

### Key Entities

- **Keystroke path**: the synchronous work driven by one edit — parse, code
  construction, fold re-application, hidden-range recomputation, text-span build.
  The feature measures it as a whole and attributes the parse's share within it.
- **Language fallback**: what the editor does when the configured language is absent
  or unrecognised. This is where the issue's premise is decided.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a 4800-line (≈300 KB) document, the highlight step with no language
  selected costs less than 5% of the same step with a language selected.
- **SC-002**: On the same document, one keystroke with no language selected completes
  in under one tenth of a second.
- **SC-003**: One keystroke with no language selected is never slower than the same
  keystroke with a language selected.
- **SC-004**: A change that makes the no-language parse cost comparable to the
  with-language parse fails the test suite.

## Assumptions

- Measurements are taken in `flutter test` (unoptimized JIT) on the development
  machine, as the repo's existing perf specs do; the ratios are the durable part.
- The document is Java-like source of ~60 characters per line, matching the repo's
  existing perf fixtures.
- "No language selected" means the controller was constructed without a `language`
  argument, which is the public API's zero-configuration path.
- Skipping the parse outright is *not* required: the measurement decides between
  skipping it and keeping it, and the outcome is recorded either way.
