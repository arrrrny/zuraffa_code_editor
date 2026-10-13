# Verification: simplify-hidden-ranges-118

Verdict: **PASS** — 8/8 mutants killed, no survivors, 100% line coverage,
net deletion in `lib` + `test`.

## Scope

`HiddenRanges` is internal (not exported from `zuraffa_code_editor.dart`) and
has exactly one construction site in `lib/`:
`hidden_ranges_builder.dart:36`. Two changes:

1. The constructor assert is tightened from
   `!ranges[i].isAfter(ranges[i - 1])` (permits touching ranges) to
   `ranges[i].start <= ranges[i - 1].end` → fail. One predicate replaces
   `_areSortedAndNotOverlapping` and rejects overlap, adjacency and
   out-of-order in the same comparison.
2. `recoverPosition`'s two run-walking `while` loops are deleted. With the
   invariant holding, a collapse is a single range: `downstream` returns
   `range.start`, `upstream` returns `range.end`.

Everything else in the method — the interpolation search, the `-1` / `+1`
cases, the single-range tail — is untouched; none of it depends on adjacency
(R3).

## Evidence

| Gate | Result |
| --- | --- |
| RED: `flutter test test/src/hidden_ranges --concurrency=2` | `+12 -1` — only "touching ranges fail the assert" fails |
| GREEN: same after T010–T012 | `+71: All tests passed!` |
| `flutter test --concurrency=2` (full suite) | 898 green (the assert trips on no file outside the two deleted) |
| `dart analyze --fatal-infos lib test` | No issues found |
| `dart format --output=none --set-exit-if-changed .` | 0 changed (308 files) |
| `tool/coverage_gate.py --min 100` | **100.00% (3548/3548 lines over 109 files)**, 9 pre-existing exemptions |
| `git diff --shortstat -- lib test` | 219 insertions, 225 deletions — net deletion (SC-5) |

## Mutation testing

`tdd/mutation_audit.py` — patterns anchored and asserted unique before use, the
lesson from cache-text-span-114.

| Mutant | Mutation | Verdict |
| --- | --- | --- |
| M1-overlapOnly | assert fails on overlap only (`<`) | KILLED |
| M2-adjacencyOnly | assert fails on adjacency only (`!=`) | KILLED |
| M3-noAssert | assert removed | KILLED |
| M4-predicateAlwaysTrue | predicate body removed | KILLED |
| M5-downstreamReturnsEnd | downstream returns `range.end` | KILLED |
| M6-upstreamReturnsStart | upstream returns `range.start` | KILLED |
| M7-downstreamAlwaysFirst | downstream returns `ranges[0].start` | KILLED |
| M8-upstreamAlwaysLast | upstream returns `ranges.last.end` | KILLED |

## Coverage

FILL.

## Notes

- The two deleted files tested a shape the package no longer has. Their
  non-adjacent content moved into `hidden_ranges_merge_invariant_test.dart`
  (the `hashCode` group included), which also pins the new invariant. Deleting
  them is a decision, not tidying: if a reviewer disagrees, restore the loops
  and the files rather than loosening the assert.
- One RED-draft correction: `cutPosition(45)` over the gapped fixture was first
  written as `34` from a mis-traced prefix sum (total hidden is 17, not the
  last range's 11). The actual is `28`.
- The gate's one uncovered line after the loop deletion was
  `text_range.dart:8` — `MyTextRange.isAfter`, whose only in-package caller was
  the deleted `_areSortedAndNotOverlapping`. The extension is exported public
  API, so the member stays and `test/src/code/text_range_test.dart` covers it
  (with `normalized`, the extension's other member) rather than the member being
  deleted or exempted.
- `git diff --shortstat` over the whole branch is a net addition only because
  `.specify/` is tracked; over `lib` + `test` it is 219/225, a net deletion
  (SC-5).
