# Conformance matrix: simplify-hidden-ranges

| ID | Requirement | Satisfied by | Proved by |
| --- | --- | --- | --- |
| FR-1 | Touching pair rejected | `_areSortedMergedAndNonAdjacent` | T002 |
| FR-2 | Gap / single / empty accepted | the same predicate, on empty and single lists | T003 |
| FR-3 | Overlap still rejected | the same predicate | T004 |
| FR-4 | `downstream` recovers the collapsing range's start | the loop removal | T005 |
| FR-5 | `upstream` recovers that range's end | the loop removal | T006 |
| FR-6 | Both hold at the first, middle and last range | the same, three positions | T005, T006 |
| FR-7 | Every other projection unchanged | nothing else edited | T007 |
| FR-8 | Folded documents still render and recover | the whole suite, unmodified | T014 |
| SC-1 | analyze clean | T015 | — |
| SC-2 | format clean | T016 | — |
| SC-3 | suite green with the two files deleted | T012, T014 | — |
| SC-4 | 100% coverage, exemptions unchanged | T017 | — |
| SC-5 | net deletion | T018 | — |
| SC-6 | mutation audit 0 survivors | T019 | M1–M8 |

## Mutation coverage of the invariant

| Aspect | Mutations | Killed by |
| --- | --- | --- |
| the overlap half of the predicate | M2, M4 | T004 |
| the adjacency half | M1 | T002 |
| the predicate's existence | M3 | T002 |
| `downstream`'s return | M5, M7 | T005 |
| `upstream`'s return | M6, M8 | T006 |
| the deleted loops | M5–M8 all assume the loops are gone | T005, T006 |

A direction mutation (M5/M6) is only killable if a test asserts the actual
value at a real collapse; a "not equal to before" assertion would not do, which
is why both tests pin absolute integers.
