# Feature Specification: pin the cost of the keystroke path when no language is selected

**Feature Branch**: `spec/no-language-parse-cost`

**Created**: 2026-10-11

**Status**: Decision recorded — the reported stall is not reproducible on this
fork; the no-language path is measured and pinned by
`test/src/code_field/no_language_keystroke_test.dart`. No code change.

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

- **SC-001**: On a 4800-line (≈85 KB) document, the highlight step with no language
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
- The document is Java-like source of ~18 characters per line (84 552 chars at
  4800 lines), the same fixture shape as the repo's existing latency guard
  `test/src/code_field/edit_latency_test.dart`, so the two guards are directly
  comparable.
- "No language selected" means the controller was constructed without a `language`
  argument, which is the public API's zero-configuration path.
- Skipping the parse outright is *not* required: the measurement decides between
  skipping it and keeping it, and the outcome is recorded either way.
- This spec answers both fork #111 (`spec`) and fork #93 (`bug`), which are the
  same upstream #246 report filed under two labels.

## Measurement (recorded)

Taken by `test/src/code_field/no_language_keystroke_test.dart` on this fork,
median of 5 after a warm-up run, five consecutive runs:

| path | `highlight.parse` | one keystroke | paste of the whole document |
|---|---|---|---|
| no language (`_languageId == ''`) | 10–18 µs | 13.1–14.5 ms | 16.1–17.0 ms |
| `java` | 78.9–96.5 ms | 119.9–129.5 ms | 124.8–129.2 ms |

Conclusions:

- **The premise is false.** `highlight` 0.7.0 resolves an empty or unknown
  language to `plaintext` — an empty `Mode` — so the no-language parse is
  ~0.1% of the no-language keystroke. There is no multi-second stall to fix.
- **Neither path reaches "~20 s"** at this size: the with-language keystroke is
  ~125 ms and the with-language paste ~127 ms, two orders of magnitude below the
  report. Whatever the report's author measured is not what this fork does —
  including the paste, which is the shape upstream #246 actually describes and
  which the same file covers (`Pasting a large document with no language does
  not block`).
- **Skipping the parse is not worth a code change.** It would remove at most
  ~18 µs from a ~14 ms keystroke and a ~17 ms paste.
- **The decision is pinned, not asserted.** The test asserts ratios between the
  two paths plus absolute bounds of 100 ms per keystroke and 1 s per paste, and a
  fault injection registering `java` under the empty language id reddens it
  (parse 80 532 µs vs the with-language 76 120 µs, keystroke 109 045 µs, parse
  share 73.9%) — so a future change that makes the no-language fallback resolve
  to a real language fails the suite instead of reaching users quietly.
