# Plan: simplify-hidden-ranges

## The change, in full

Two files, net deletion (SC-5).

**1. `lib/src/hidden_ranges/hidden_ranges.dart` — the assert.**

```dart
  HiddenRanges({required this.ranges, required this.textLength})
    : assert(
        _areSortedMergedAndNonAdjacent(ranges),
        'Ranges must be sorted, non-overlapping and non-adjacent. '
            '`HiddenRangesBuilder` merges touching ranges, so a list that '
            'reaches here with `ranges[i].start == ranges[i - 1].end` was '
            'not built by it.',
      ),
```

with

```dart
  /// The invariant `HiddenRangesBuilder._merge` produces: sorted, and a gap of
  /// at least one character between every pair.
  ///
  /// The algorithms below rely on the gap — a run of touching ranges would
  /// collapse them onto one visible position and make `recoverPosition`'s
  /// affinity choice ambiguous.
  static bool _areSortedMergedAndNonAdjacent(List<HiddenRange> ranges) {
    for (int i = ranges.length; --i >= 1;) {
      if (ranges[i].start <= ranges[i - 1].end) {
        return false;
      }
    }

    return true;
  }
```

Note what `ranges[i].start <= ranges[i - 1].end` buys in one comparison: the
old `isAfter` needed `start >= previous.end` to *pass* and said nothing about
which side failed. The new form fails eagerly on both overlap and adjacency,
and the two conditions collapse into one expression, so the old
`_areSortedAndNotOverlapping` is deleted rather than edited alongside its
replacement.

**2. `lib/src/hidden_ranges/hidden_ranges.dart` — `recoverPosition`.**

The two run-walking loops go. `downstream` returns `ranges[rangeIndex].start`,
`upstream` returns `ranges[rangeIndex].end`, each directly:

```dart
        case 0: // position is at the range collapse.
          switch (placeHiddenRanges) {
            case TextAffinity.downstream:
              return range.start;
            case TextAffinity.upstream:
              return range.end;
          }
```

Everything else in the method — the interpolation search, the `-1` and `+1`
cases, the single-range tail at `:309-315` — is untouched, because R3
established none of it depends on adjacency.

## Tests

`test/src/hidden_ranges/hidden_ranges_merge_invariant_test.dart`, written RED
first, then the implementation:

| Test | Covers |
| --- | --- |
| a touching pair is rejected | FR-1 |
| a gap is accepted, a single range is accepted, `empty` is accepted | FR-2 |
| an overlapping pair is rejected | FR-3 |
| downstream recovers the collapsing range's start — first, middle and last range | FR-4, FR-6 |
| upstream recovers that range's end — first, middle and last range | FR-5, FR-6 |
| the projections move together | FR-7 |

**Deleted:** `test/src/hidden_ranges/hidden_ranges_adjacent_recover_test.dart`
and `test/src/hidden_ranges/hidden_ranges_collapse_test.dart`. Both files exist
to pin a shape the class is about to refuse; replacing them with the invariant
test is what keeps the change honest rather than a quiet weakening of the suite.
`hidden_ranges_collapse_test.dart` also holds a `hashCode` group, which moves
into the new file — the code it tests (`:369-377`) is untouched and still
needs its pin.

**Unmodified:** everything else under `test/src/hidden_ranges/`, plus
`test/src/code/code_hidden_ranges_test.dart`,
`test/src/search/cut_search_result_test.dart`, and every folding and
`CodeController` test.

## Complexity budget

- One new private static predicate, replacing one.
- Two `while` loops and their comments deleted.
- One new test file, two deleted.
- No new public identifier, no new type, no new field, no new parameter.

## Conformance

`.specify/specs/simplify-hidden-ranges-118/code_matrix.md`.
