# TDD Test List: mounted-disposed-checks

Feature: .specify/bugs/mounted-disposed-checks
Spec: ./spec.md · Engine: raw (zfa missing — LLM-guided derivation)

## Outer-loop behaviors (from acceptance criteria)

| ID | Behavior | Traces to | Test file | Status |
|----|----------|-----------|-----------|--------|
| B1 | Disposing the gutter error popup between mouse-exit and the 50ms delayed callback does not throw; nothing touches the disposed State afterwards | AC1 | `test/src/gutter/error_popup_dispose_test.dart` | GREEN |
| B2 | Pressing Enter with search shown, then disposing the CodeController within the same event-loop turn, does not throw | AC2 | `test/src/search/search_enter_dispose_test.dart` | GREEN |
| B3 | Unchanged happy path: the error popup still closes when the mouse leaves it; Enter still moves focus to the pattern field | AC3 | covered by B1/B2 test files (post-fix assertions) | GREEN |

## Guard (not a new behavior)

| ID | Behavior | Traces to | Test file | Status |
|----|----------|-----------|-----------|--------|
| G1 | The full pre-existing suite stays green | AC4 | `flutter test` | GREEN (299 total) |

## Inner-loop units

None — both defects are lifecycle guards inside widget/controller code; the
outer widget tests are the honest level. No separate pure-unit seam is needed.

## Red scenarios (must fail before the fix)

- B1: unmount during the 50ms delay → `setState() called after dispose()`.
- B2: dispose during the `Future.delayed(Duration.zero)` gap → focus request on
  a disposed FocusNode throws.
