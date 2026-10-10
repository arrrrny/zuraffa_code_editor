# TDD cycle log: Sluggish performance past a few hundred rows

Date: 2026-10-10 · Branch: `perf/edit-latency-past-few-hundred-rows` (based on
`origin/master` @ `df71234`)

A performance bug starts with no red test: "very sluggish" is not a failing
assertion, and the first useful thing to write is not a test but a measurement.
So the cycle here ran measurement → red (fault injected) → green, and the
permanent test is the measurement itself.

## 1. Turn the report into numbers

Built a throwaway `testWidgets` harness: a Java-like document of N lines, one
character inserted in the middle, `Stopwatch` around `controller.value = …`,
median over several keystrokes, N over {200, 1000, 3000}.

First useful result — the shape, which the report could not distinguish:

```
before, median keystroke   200 lines: 7.6 ms
                          1000 lines: 28.6 ms
                          3000 lines: 88.7 ms
```

Per line that is 38 µs, 29 µs, 30 µs — flat to falling. The bug is not a
quadratic algorithm; it is a linear cost with a large constant, tens of
milliseconds per keystroke at the reported sizes, which is a few
keystrokes/second.

## 2. Measure the growth, not just the level

Confirmed by the per-line figures above. This is what the committed benchmark
asserts, and it is why the acceptance criterion "growth is sub-linear" is
recorded in `spec.md` as not met: there was never a super-linear term to remove.

## 3. Attribute the constant

Instrumented the edit path with temporary `Stopwatch` prints (backed up outside
the tree, reverted before committing), and then measured the same steps in
isolation in the same harness. Both agree: `highlight.parse` of the whole
document is ~57-61% of a keystroke, the rest of `Code(...)` ~17%, the second
`cutHighlighted` + `splitLines` inside `Code.foldedAs` ~6-10%, and
`Autocompleter.setText` re-indexing every word ~9-12%.

`highlight.parse` has no incremental API and no seam in this package, so the
actionable part is the other two: both are O(document) work that a single
character edit does not require.

## 4. RED — inject the fault

Both optimizations are observable by object identity, which is how the tests pin
them. On unmodified `origin/master`, with the two new tests already written:

```
00:00 +16 -2: Some tests failed.
  hidden_ranges_test.dart: HiddenRanges. cutHighlighted. Nothing hidden -> returned as is [E]
  code_hidden_ranges_test.dart: Code. Hidden ranges. foldedAs an unfolded code keeps the visible text and highlight [E]
```

For the autocompleter, the red is the reason for the rebuild path rather than
the optimization. Replacing the rebuild with `AutoComplete.delete` — the
"obvious" incremental form — prints:

```
Autocompleter Drops a word that disappears, and one that prefixes another
  Expected: ['foobar']
    Actual: ['foo', 'foobar']
```

`AutoComplete.delete('foo')` leaves `foo` in the index when `foobar` is still
there, so the removal path has to rebuild.

## 5. GREEN

- `Code._copyWithFolding` reuses `visibleText` / `visibleHighlighted` when the
  merged hidden ranges equal the receiver's.
- `HiddenRanges.cutHighlighted` returns `highlighted` when `ranges` is empty.
- `Autocompleter` keeps the indexed word set per key and enters only new words,
  rebuilding when a word disappears.

Isolated, per keystroke at 3000 lines: `Code.foldedAs` 15.9 ms → 0.13 ms,
`Autocompleter.setText` 19.2 ms → 14.7 ms.

## 6. Measure again, carefully

The first A/B attempt measured the three sizes in ascending order and reported
the 3000-line case at 186 ms — against 73 ms for the same document measured
first in a leaner harness. Building and dropping the large documents churns the
debug heap enough to inflate whatever is measured after them. The harness now
measures largest first after a warm-up, and the comparison is run alternately,
three times per variant:

```
3000 lines  before 83.6 / 88.7 / 93.5 ms   after 72.2 / 77.9 / 78.4 ms
1000 lines  before 25.7 / 29.0 / 28.6 ms   after 22.9 / 24.6 / 25.4 ms
 200 lines  before 6.58 / 7.83 / 7.57 ms   after 4.60 / 5.17 / 4.97 ms
```

Every "after" run beat every "before" run at every size: −34% / −14% / −12%.

## 7. REFACTOR

No new abstraction. The three changes are the smallest form of each
observation:

- **Considered and rejected:** `foldedAs` returning `this` when the old code has
  no folded blocks. Shorter, but wrong: `foldedBlocks` still has to come from
  the argument (`applyHistoryRecord` folds *into* a code that has nothing
  folded), so the reuse had to be keyed on the hidden ranges, which is the
  actual invariant.
- **Considered and rejected:** reporting the changed range to `setText` so the
  word split is incremental too. It would widen the public API of
  `Autocompleter` for the remaining ~5 ms, and the split is a linear scan, not
  the trie work that dominated.
- **Considered and rejected:** caching `highlight.parse`. The package has no
  seam to parse only the changed region; that is lazy per-line highlighting
  (fork issue #22), a different design, and it is recorded in `fix.md` as the
  remaining ceiling.

## 8. Verification

```
flutter test                                            → 575/575
dart analyze --fatal-infos lib test tool                → No issues found!
dart format --output=none --set-exit-if-changed .       → no changes
python3 tool/coverage_gate.py --min 100                 → 100.00% (3100/3100), exit 0
```

No exemption was added to `tool/coverage_gate.py`: the new branches are covered
by tests 2, 3 and 5.
