# #18 — Large files render blank lines past ~1000 lines; high CPU and RAM

- **Status:** fixed (the rendering half); the CPU/RAM half is a separate
  performance question tracked by #22
- **Label:** `bug`
- **Source:** upstream `akvelon/flutter-code-editor#283`

## Reported symptom

> If I open a file with more 1000 lines it does not not display correctly after
> a certain point it only shows blank lines. Also for these large files widget
> uses a lot of CPU and RAM.

Upstream commenters tie it to the gutter: peter-kal reports the symptom is
"fixed by adding height to the GutterStyle property", and ViscousPot
prototyped chunked loading on a fork. That points at the gutter/line-height
sync, the same subsystem as #19 and the gutter alignment work.

## Where the bug actually lives

Not in the code's rendering — the code area's scroll extent is exactly
`lines × lineHeight` at every size measured (60/200/400/600/800/1000/1500
lines). It is in the gutter's `Table`, and specifically in the width of the
line-number column:

```
style.width (default 80.0)
  − 16  issue column
  − 16  folding column
  − 10  style.margin, the gap to the code
  ────
  = 38 px for the numbers
```

A line number is a `Text` in the only flex column, so it gets exactly that.
`38 px` is enough for two digits and nothing more, so from the first
three-digit number on the number wraps:

```
number "1"    -> Size(38.0, 24.0)   one line
number "99"   -> Size(38.0, 24.0)   one line
number "100"  -> Size(38.0, 48.0)   wraps — twice the line height
number "1000" -> Size(38.0, 48.0)   wraps
```

Row pitch in the gutter is 24.00 px for rows 1→99 and 48.00 px for rows
100→1001. A 1200-line document therefore builds a gutter 55272 px tall against
a code area of 28824 px, and the two scroll positions end at different places
(54776 vs 28328). Scrolling to the bottom of the code shows rows whose numbers
no longer line up with them, and the rows on screen run out of numbers above
them — which is what "blank lines" looks like from the outside.

Which line count triggers it is a font question, not a line-count one: the test
font advances a digit by 16 px so the wrap lands at 100, a real one by roughly
half that so it lands near 10 000. The shape of the bug is the same either way,
so the tests below assert the invariant rather than a line count.

## The change

`lib/src/gutter/gutter.dart`

- The number column's width is now
  `max(requestedWidth − fixedColumns − margin, widestVisibleNumberWidth)` and
  the gutter is laid out from that. A document whose numbers fit keeps the
  exact geometry it had — 80.0 requested still renders a 70.0 px table. A
  document whose numbers do not fit gets a wider gutter instead of wrapped
  numbers.
- `_widestNumberWidth()` measures the widest visible line number with a
  `TextPainter` in the number style. It returns 0 when the numbers are hidden
  or there is nothing to number, so the requested width is left untouched in
  both cases.
- The number `Text` is pinned to one line (`softWrap: false`, `maxLines: 1`),
  so a row can no longer be taller than the line it labels even if some other
  path leaves the column narrow.

`tool/coverage_gate.py` — the `EXEMPT_LINES` key for `gutter.dart` keys a dead
fold-toggle lambda by line number; the code added above it moved it 165 → 212.
Only the key moved — the proof comment is unchanged and the exempted-line count
stays 13.

## Tests

`test/src/gutter/gutter_line_number_column_width_test.dart` — four tests over a
1200-line document:

| # | Test | Pin |
|---|------|-----|
| 1 | the widest visible number fits on one line | every number box is exactly the code line height |
| 2 | the gutter table is one code line tall per visible row | table height == visibleRows × lineHeight |
| 3 | the gutter scrolls as far as the code does | gutter maxScrollExtent == code maxScrollExtent |
| 4 | the gutter stays the requested width while numbers fit | 40-line doc still renders a 70.0 px table |

Test 4 is the backward-compatibility guard: it passes with and without the
fix, and exists so a future change cannot quietly widen every gutter.

## Fault-detecting power

Measured by reverting only `lib/src/gutter/gutter.dart`:

```
Expected: a numeric value within <0.001> of <24.0>
  Actual: <48.0>
a line number wrapped: the row is 48.0 tall against a code line of 24.0

Expected: a numeric value within <0.001> of <28824.0>
  Actual: <55272.0>

Expected: a numeric value within <0.001> of <28328.0>
  Actual: <54776.0>
```

i.e. tests 1–3 fail, and test 4 stays green.

## Conclusion

The rendering half of #18 is fixed. The CPU/RAM half is a different problem —
building every row of a 1000-line document as a `TableRow` is what it costs —
and is what #22 (lazy loading / chunked rendering) is for; #39 already removed
the per-keystroke rebuild that made it worse while typing.

## Gate note

`EXEMPT_LINES` key for `gutter.dart` moved 165 → 212 (see above). Coverage is
100.00 % (3132/3132), and the full suite is 587 tests.
