# Phase 0 Research — no-language keystroke cost (#111)

Feature: `.specify/specs/no-language-parse-cost/spec.md`

## Decision 1: no language resolves to `plaintext`, an empty mode

**Decision**: `CodeController` calls
`highlight.parse(text, language: _languageId)` unconditionally
(`lib/src/code_field/code_controller.dart:1013`), and with no language
configured `_languageId` is `''` (`lib/src/code_field/code_controller.dart:97`,
set only by `setLanguage` at line 274). `highlight` 0.7.0 resolves an
unregistered name to `plaintext`.

**Rationale**: `highlight-0.7.0/lib/src/highlight.dart:271` —
`var langMode = _languageMode = _getLanguage(language) ?? plaintext;`, and
`_getLanguage` returns null for a name it does not know
(`highlight-0.7.0/lib/src/highlight.dart:497-501`). `plaintext` is
`Mode(refs: {}, disableAutodetect: true)`
(`highlight-0.7.0/lib/languages/plaintext.dart:6`): no keywords, no sub-modes,
no auto-detection, so the lexer loop has nothing to emit and the parse is a
single walk producing one text node.

**Alternatives considered**:
- Add an `if (_languageId.isEmpty) skip parse` guard in `_createCode`.
  **Rejected**: measured saving is ~3.0 ms of a 43 ms keystroke (7%), it
  changes `Code.highlighted` from a one-node tree to an empty tree for every
  no-language consumer (a behavioural change with its own regression surface),
  and it buys nothing against the reported ~20 s symptom, which does not occur.

## Decision 2: the assertion is a ratio, never an absolute millisecond budget

**Decision**: the pin compares the no-language path against the
with-language path on the *same* document and the *same* machine in the same
test body.

**Rationale**: `flutter test` runs the unoptimized JIT; absolute timings on
CI hardware have been observed to differ by more than 2× from the author's
machine for the *same* code (the comments in
`test/src/code_field/edit_latency_test.dart:134-140` record exactly this). A
ratio between two measurements taken milliseconds apart on the same code path
is stable to within a few percent, which is what
`.specify/specs/lazy-loading-long-text/test-list.md` already relies on for the
#22 guard.

**Alternatives considered**:
- Absolute budget (e.g. "parse must be < 10 ms"). **Rejected as flaky** per the
  above; it would redden on slow CI runners for reasons unrelated to the code.
- Linearity pin only (reuse `edit_latency_test.dart` as-is). **Rejected**: that
  guard asserts per-line cost stays flat across document sizes *with a
  language*. It cannot see a regression that makes the *no-language* path
  expensive — which is precisely the class of regression this feature exists
  to catch (FR-004, SC-004).

## Decision 3: document fixture matches the existing latency guard

**Decision**: the measurement uses a 4800-line Java-like document built by a
local fixture, not a checked-in binary fixture.

**Rationale**: `test/src/code_field/edit_latency_test.dart:31` already defines
`_document(int lines)` producing ~18 chars/line with a comment, a method head,
a declaration, a return and a closing brace every five lines — 84 552 chars at
4800 lines. Reusing the same shape keeps the two latency guards comparable and
avoids a second fixture to maintain. 4800 lines is the size the issue names;
its byte size is not stated in the report, and the conclusion does not depend
on it (see Decision 2 — the ratio is what is asserted).

**Alternatives considered**:
- A `String.fromCharCodes` blob. **Rejected**: no realistic keyword/comment
  density, and it does not match the fixture the existing guard uses.
- Padding the fixture to ~60 chars/line to reach ~300 KB. **Rejected**: a
  second fixture shape to maintain, and the conclusion holds at both sizes — the
  no-language parse is trivially cheap either way, so a bigger document only
  makes the test slower.

## Decision 4: the no-language controller is built directly, not via `createController`

**Decision**: the new test constructs its own `CodeController` with no
`setLanguage` call.

**Rationale**: `test/src/common/create_app.dart:56` defaults
`language: language ?? java`, so `createController(text)` with no language
*yields java*. The zero-configuration path the issue describes is a controller
that never had a language set. Changing the shared helper's default would
silently re-point every existing test.

**Alternatives considered**:
- Add a `language:` null passthrough to `createController`. **Rejected**: same
  blast radius as above, across the whole `test/` tree.
- Use `pumpController` in a widget test. **Rejected**: the keystroke path is
  synchronous controller work; a widget test adds pump overhead that dominates
  the measurement.

## Open questions resolved

No `NEEDS CLARIFICATION` items remain. The measurement numbers quoted in the
spec (3.0 ms no-language vs 318.2 ms with-language parse; 43 ms vs 378 ms
keystroke median at 4800 lines) were taken with throwaway probes before the
spec was written and are re-taken inside the test's own body so the printed
values in CI come from the same code the assertions judge.
