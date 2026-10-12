# Verification: batch-fold-blocks-116

Verdict: **PASS** — 3/4 mutants killed, 1 equivalent (proven, see below),
100% line coverage.

## Scope

`CodeController.foldBlocks(Iterable<FoldableBlock>)` folds many blocks in one
pass: one new `Code`, one value assignment and one listener notification
regardless of how many blocks are folded. A block that is already folded, or
that the current code no longer holds, is skipped; when nothing remains to
fold, no value is assigned. `foldImports()` and `foldOutsideSections()`
delegate to it and both upstream TODOs are gone.

## Evidence

| Gate | Result |
| --- | --- |
| `flutter test test/src/code_field/` + `test/src/code/` + folding/history suites | 124 green (characterization, untouched) |
| `flutter test test/src/code_field/code_controller_fold_blocks_test.dart` | 6 green |
| `flutter test` (full suite) | 836 green (825 post-#135 master + 6 net; the count moved when `c70a5ae` landed its own JS/Scala regression tests) |
| `dart format --set-exit-if-changed` | clean |
| `flutter analyze --fatal-infos` | No issues found |
| `flutter test --coverage` + `tool/coverage_gate.py --min 100` | **100.00%** — OK |

## Mutation testing

Four mutants against the behaviour suites (`code_controller_fold_blocks_test.dart`
plus the characterization folding suites that pin `foldImports` /
`foldOutsideSections` through the new path):

| Mutant | Target | Verdict |
| --- | --- |
| M-loop-assign | value assigned inside the fold loop (one per block) | KILLED — "One value assignment and one listener notification for N blocks" |
| M-stale-not-skipped | stale blocks folded anyway | KILLED — "Skips stale blocks the current code no longer holds" |
| M-folded-not-skipped | already-folded blocks re-folded | KILLED — "Skips already-folded blocks without extra work" |
| M-no-skip | no early return when nothing folded | **EQUIVALENT** (proof below) |

### M-no-skip is an equivalent mutant, and here is the proof

Removing

```dart
if (identical(newCode, _code)) {
  return;
}
```

from `foldBlocks` changes no observable behaviour, for two reasons that
compose:

1. `Code.foldedBlock` returns `this` — the very same instance — for a block
   that is already folded or that the code does not hold (pinned by the new
   test "A fold that cannot happen leaves the Code itself untouched"). So
   when nothing folds, `newCode` *is* `_code`: the loop's only other outcome
   (a fresh `Code` with a new hidden range) cannot happen.
2. `TextEditingController`'s own `value` setter returns early when the text,
   the selection and the composing range are all unchanged, so even the
   assignment that survives the guard's removal notifies no listener.

Empirical confirmation, not just reasoning: a differential probe ran the same
scenario (every collapsed and non-collapsed selection in the visible text of
a folded `TwoMethodsSnippet`, selection first then fold so the fold's
selection memory is live) with and without the guard, and recorded the
notification count, the value after the no-op batch, the selection after
unfolding and the `Code` identity. The two signatures were byte-identical.

The pin added alongside is the honest fence: it asserts the `identical`
contract of `Code.foldedBlock` on the skip paths, so if a future change makes
`foldedBlock` hand back an equal-but-fresh `Code`, the guard becomes
load-bearing and that test fails first — at which point a kill test for the
guard itself (a notification count on a no-op batch) is the right follow-up.
The guard is kept as the explicit statement of the "no value is assigned"
contract in the doc comment, not as dead weight.

## Coverage

`tool/coverage_gate.py` at 100% with no new exemptions: `foldBlocks`,
`Code.foldedBlock` and both delegating helpers are fully covered by the six
behaviour tests, and the characterization suites cover the two helpers through
their existing paths.

## Perf note

`no_language_keystroke_test.dart` can red under `--coverage` on this host from
machine load (other repos' `flutter_tester` processes compete for it); it
passes standalone and on clean master. No code change — flagged so CI noise is
not mistaken for a regression.
