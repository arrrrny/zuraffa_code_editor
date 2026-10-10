# TDD Test List: Sluggish performance past a few hundred rows

- **Slug**: performance-hundred-rows
- **Issue**: 39

A performance fix has one test that can fail honestly — the benchmark that
measures the cost — plus behaviour pins proving the optimization did not change
what the editor does. Both are listed.

| # | Test | Kind | Status |
|---|---|---|---|
| 1 | `A keystroke gets no more expensive per line as the document grows` | benchmark + super-linear guard | pass |
| 2 | `foldedAs an unfolded code keeps the visible text and highlight` | **fault-detecting** pin for change 1 | pass |
| 3 | `cutHighlighted. Nothing hidden -> returned as is` | **fault-detecting** pin for change 2 | pass |
| 4 | `Words added by typing match a fresh index` | behaviour pin for change 3 | pass |
| 5 | `Drops a word that disappears, and one that prefixes another` | behaviour pin for change 3 | pass |

## Test 1 — `test/src/code_field/edit_latency_test.dart`

Measures the median keystroke at 200, 1000 and 3000 lines and asserts that the
per-line cost at 3000 lines is under 3x the per-line cost at 200. Measured
verdict: 27.3 vs 24.3 µs/line, i.e. 1.1x, so growth is linear.

It is a benchmark first and a guard second: it also prints the numbers, so the
next report of "sluggish past a few hundred rows" starts from data instead of a
sentence. The bound is deliberately loose (see the comment in the file) because
`flutter test` runs the unoptimized JIT on a shared CI machine; what it is meant
to catch is a quadratic step, which with a 15x line spread reads as 15x, not
1.1x.

Fault detection, measured: **it does not fail on `master`** — the growth was
already linear, which is the finding of this bug. It fails on an actual
super-linear regression, not on the absence of the optimization.

## Tests 2 and 3 — the optimization pins

Both assert object identity, which is exactly the property the optimization
creates and the only cheap way to observe "the tree was not rebuilt".

- Test 2 builds a `Code` outside the file's `setUp` (no read-only sections, so
  no hidden ranges) and folds it as a `Code` that has nothing folded. Before
  change 1 the result's `visibleHighlighted` is a fresh tree, so
  `identical(...)` is false.
- Test 3 cuts a highlight with an empty range list and expects the very same
  `Result` back, plus the same HTML.

Measured verdict on unmodified `origin/master`:

```
00:00 +16 -2: Some tests failed.
  hidden_ranges_test.dart: HiddenRanges. cutHighlighted. Nothing hidden -> returned as is [E]
  code_hidden_ranges_test.dart: Code. Hidden ranges. foldedAs an unfolded code keeps the visible text and highlight [E]
```

Both pass with the change.

## Tests 4 and 5 — the autocompleter

The incremental index has to produce what the full rebuild produced, so test 4
compares a key typed into twice against a fresh `Autocompleter` given the final
text: the suggestion lists must be equal. Test 5 pins the case that forces the
rebuild path — a word that disappears, and specifically one that is the prefix
of another word, which `AutoComplete.delete` cannot remove on its own.

These two pass on `master` as well: the optimization is invisible in behaviour
by design, and these pin that. Their fault-detecting power is over the *reason*
for the rebuild branch (test 5 fails if the rebuild is replaced with
`AutoComplete.delete`), not over the optimization itself.
