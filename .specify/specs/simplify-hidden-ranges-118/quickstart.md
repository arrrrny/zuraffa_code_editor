# Quickstart: simplify-hidden-ranges

## The invariant, one line

For every `i > 0`: `ranges[i].start > ranges[i - 1].end`.

`HiddenRangesBuilder._merge` has always produced it. The constructor now asserts
it, and the code that existed for the weaker invariant is gone.

## Reproduce the waste

Two ranges that touch collapse onto the same visible position, so recovering that
position is ambiguous: `downstream` and `upstream` have to choose an end, and the
choice requires knowing where the run *starts* and *stops*. That is the two
`while` loops in `recoverPosition`. Under the merged invariant at most one range
collapses at any position, so the loops can never iterate.

## The change, in full

`lib/src/hidden_ranges/hidden_ranges.dart` only — see `plan.md`. One predicate
replacing another, two loops deleted, two test files replaced by one.

## Run the gates

```sh
flutter test test/src/hidden_ranges --concurrency=2
flutter test --concurrency=2
dart analyze --fatal-infos lib test
dart format --output=none --set-exit-if-changed .
bash /tmp/gate.sh /Users/arrrrny/Developer/zuraffa_118 /tmp/gate118.log
python3 .specify/specs/simplify-hidden-ranges-118/tdd/mutation_audit.py
git diff --shortstat   # must be a net deletion
```

## What to look at when it breaks

- **The assert trips in a file that is not one of the two being deleted.** That
  file constructs a list no internal caller can produce. Fix the file; do not
  loosen the predicate (R4).
- **A `recoverPosition` value changed.** The loops were dead, so this means the
  position was not actually at a collapse, or the range it collapsed at was not
  the one the interpolation search settled on. Check the position against
  `hiddenCharactersBeforeRanges` before suspecting the loops.
- **`cutPosition` disagrees.** Unrelated to this change — see R3 and the
  overshoot test.
