# Fix: Sluggish performance past a few hundred rows

- **Slug**: performance-hundred-rows
- **Issue**: 39 (upstream `akvelon/flutter-code-editor#255`)
- **Status**: measured, optimized, benchmark committed

## Measured before/after

Median time of one keystroke — one character inserted in the middle of a
Java-like document — on the unoptimized JIT `flutter test` runs on. Three runs
per column, alternating, taking the median of the three; each run is itself the
median of 8 keystrokes.

| lines | before (`origin/master`) | after | change |
|---|---|---|---|
| 200 | 7.57 ms | 4.97 ms | −34% |
| 1000 | 28.6 ms | 24.6 ms | −14% |
| 3000 | 88.7 ms | 77.9 ms | −12% |

Every "after" run beat every "before" run at every size. Per-line cost is flat
(≈25 µs/line at 200 lines, ≈26 µs/line at 3000), so growth is linear in rows —
there is no super-linear term to remove, the problem is the size of the linear
constant.

## Change 1 — do not rebuild the visible highlight twice per keystroke

`lib/src/code/code.dart`, `Code._copyWithFolding`.

Every keystroke ends in `CodeController._updateCode`:

```dart
final newCode = _createCode(text);   // Code(...) — also computes visibleHighlighted
_code = newCode.foldedAs(_code);     // _copyWithFolding — computed it again
```

`foldedAs` exists to carry folded blocks from the old code into the new one, and
it derives the result's hidden ranges from the *new* code's builder. When
nothing is folded — every keystroke of every document the user has not folded
anything in — the matched set is empty, the merged hidden ranges are exactly the
ones `_createCode` already built, and the second `cutHighlighted(highlighted)`
+ `splitLines()` walks and reallocates the whole highlight tree for a value
equal to the one the receiver already holds.

Measured directly, per keystroke: `Code.foldedAs` cost **1.22 / 3.69 / 15.9 ms**
at 200 / 1000 / 3000 lines before, and **0.07 / 0.11 / 0.13 ms** after. Those
figures come from an isolated harness and overstate the in-pipeline cost, which
is why the end-to-end table above improves by less than their sum.

`visibleText` and `visibleHighlighted` are derived from the full text, the
highlighted tree, and the hidden ranges — nothing else. So the reuse is exact
when the hidden ranges are equal, which is checked with the value equality
`HiddenRanges` already implements. `foldedBlocks` is still taken from the
argument, so the fold state is unaffected.

## Change 2 — `cutHighlighted` is the identity when nothing is hidden

`lib/src/hidden_ranges/hidden_ranges.dart`.

`cutString` already returns its input untouched when `ranges` is empty, so
`cutHighlighted` with no ranges produced a structurally identical copy of the
entire node tree. That is the case for every document with no folded blocks,
no hidden service comments and no named sections — which is what an editor
typing into an ordinary file looks like. Returning `highlighted` unchanged also
makes change 1's fast path cheap.

## Change 3 — index only the words that appeared, not the whole document

`lib/src/autocomplete/autocompleter.dart`.

`CodeController.value=` calls `autocompleter.setText(this, text)` on every text
change, and `setText` called `clearEntries()` followed by re-entering **every
word of the document** into the autotrie. One typed character changes at most a
couple of words, so the index is now updated with the difference.

Typing only ever adds words, so the common path is a single set difference and
an `enterList` of the new words; a word that disappears triggers a rebuild,
because `AutoComplete.delete` keeps a word in the index when it is the prefix of
another one (see `test/src/autocomplete/autocompleter_test.dart`, "Drops a word
that disappears, and one that prefixes another").

Measured directly, per keystroke: `Autocompleter.setText` cost
**1.58 / 5.70 / 19.2 ms** at 200 / 1000 / 3000 lines before, and
**1.85 / 4.88 / 14.7 ms** after. What remains is the word split, which is a
linear scan of the document; it is only avoidable by having the caller report
the changed range, which would widen the public `setText` API for the rest of
the 5 ms.

## The remaining ceiling

Temporary `Stopwatch` instrumentation of the edit path, and isolated
measurements of the same steps, both put `highlight.parse` of the whole document
at ~57-61% of a keystroke at 3000 lines — the single largest cost, and one this
change does not touch. It runs on the full text every time, is linear, and the
package has no seam to parse only the changed region: `highlight` has no
incremental API. The reported sluggishness is survivable at a few hundred rows
and not at a few thousand largely because of that one call, and removing it is
what lazy per-line highlighting (fork issue #22) would do — a different design,
not a fix to this one.

## Verification

- `flutter test test/src/code_field/edit_latency_test.dart` — the committed
  benchmark; prints per-line latency at 200/1000/3000 lines and fails on
  super-linear growth (3x per-line bound, ~1.1x measured).
- `flutter test` — 575/575.
- `dart analyze --fatal-infos lib test tool` — no issues.
- `dart format --output=none --set-exit-if-changed .` — clean.
- `python3 tool/coverage_gate.py --min 100` — 100.00% (3100/3100). No new
  exemption was added; the three new branches are each covered by a test.
