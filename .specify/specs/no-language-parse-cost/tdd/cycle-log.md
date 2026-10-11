# Cycle log — no-language keystroke cost (#111)

Feature: `.specify/specs/no-language-parse-cost/spec.md`
Test list: `.specify/specs/no-language-parse-cost/tdd/test-list.md`

## Baseline (before the loop)

`master` @ `c8c47f5`. `flutter test` green; the suite is the baseline the new
file joins. No `lib/` change is planned, so there is no red to start from — the
finding of this feature *is* that the reported behaviour does not exist. The
honest loop output is therefore: write the pin, prove it is not vacuous by fault
injection, record the green.

## Cycle 1 — behavior: US1-AC1 (SC-001…SC-004)

**RED**: n/a — the assertions describe what the code already does on the
unmodified tree. Recorded rather than forced: a manufactured red would mean
demonstrating that the editor is slow with no language, which it is not.

**GREEN** (`test/src/code_field/no_language_keystroke_test.dart`, five
consecutive runs, median of 5 after a warm-up run):

```text
highlight.parse  no language: 10us / 11us / 11us / 16us / 18us
highlight.parse  java:        81604us / 81074us / 96509us / 80681us / 78882us
keystroke median  no language: 13139us / 13986us / 14475us / 13871us / 14060us
keystroke median  java:        127246us / 123692us / 129519us / 122746us / 124255us
```

Parse share of the no-language keystroke: 0.1% in every run. Keystroke ratio
(no-language / with-language): 0.105–0.117 in every run.

**Not vacuous**: `highlight.registerLanguage('', java)` injected before the
no-language measurement moves the parse to 80 532 µs against the with-language
76 120 µs (ratio 1.06), the keystroke to 109 045 µs and the parse share to
73.9%, which reddens SC-002 (bound 100 000 µs) and would redden SC-001 (budget
3 806 µs). Injection removed after measurement; the scratch copy
(`test/tmp_fault_111_test.dart`) was deleted and never committed.

## Cycle 2 — behavior: US1-edge (FR-003)

**GREEN**: the unresolvable-name parse median agrees with the empty-id median
within 2× (both are the same empty `plaintext` mode, so the two medians differ
only by machine noise).

## Cycle 3 — no further behaviours

The feature has no inner-loop units (no `lib/` change) and no remaining
acceptance criteria. The loop ends here rather than inventing a behaviour to
drive.

## Blockers / honest stops

None. One process deviation is recorded: the usual red-first step could not be
performed because the premise of the issue is false on this fork — the
no-language keystroke is already ~14 ms against ~125 ms with a language. Rather
than manufacture a red, the fault injection above is the evidence that the pin
can fail, which is the property a red is normally used to establish.
