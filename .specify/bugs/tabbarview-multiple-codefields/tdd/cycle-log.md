# #26 — cycle log

## Red

Not applicable: the reported crash does not reproduce on master 3362a26, so
there was no failing test to write first. The tests were written as a
characterisation of the current — non-crashing — behaviour.

What was tried and found green:

- TabBarView with 3 tabs, switching forward and back
- TabBarView with initialIndex on the last of 4 tabs
- rebuilding with fewer tabs while one is on screen
- IndexedStack with an inactive index
- an Offstage sibling
- two CodeFields in a Column

A widget-tree probe confirmed why: TabBarView builds only the tab that is on
screen (1 CodeField alive at a time), so the CodeField whose initState
post-frame callback runs has always been laid out by then, and the null read
behind the reported stack never happens.

## Green

- `flutter test test/src/code_field/tabbarview_multiple_codefields_test.dart` — 3 passed

## Residual

`code_field.dart:312-313` kept the unguarded `!`s in the first revision. The
review follow-up on this branch replaced them with `rebuild()`'s
`currentContext` guard once the review showed the recorded gate rationale for
the deferral did not hold; recorded in `spec.md` and `fix.md`.
