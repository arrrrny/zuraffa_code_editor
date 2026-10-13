# Test list: gutter-overflows-narrow-field

| # | Test | Type |
|---|---|---|
| 1 | a field narrower than the gutter keeps the gutter inside it — 60 px field, the gutter's rect stays inside the field's in both axes, at a non-zero width | widget (red on master: `A RenderFlex overflowed by 28 pixels`, gutter right edge 28 px past the field's) |
| 2 | the numbers still render, inside the field — every line-number rect is inside the field's rect at 60 px | widget (red on master: numbers paint past the edge) |
| 3 | no width in the range overflows the row — a sweep of 44/60/80/100/120/150/170/200/320 px, each with a framework-error check and a containment check | widget (red on master: overflows at 44, 60, 80, 100, 120, 150, 170) |
| 4 | the code area keeps every pixel the gutter is not using — `codeArea.width == field.width - 8 - gutter.width` at a 300 px field | widget (green on master; the guard that makes a `Flexible` gutter ineligible — it reddens three existing suites) |
| 5 | a field that can hold the gutter gets the width it asked for — 400 px field, the gutter is exactly `GutterStyle.width` | widget (green on master; a regression guard on the fix) |
| 6 | an oversized gutter is capped, not honoured past the field — `GutterStyle(width: 200)` in a 60 px field: capped, and still non-zero | widget (red on master: `A RenderFlex overflowed by 148 pixels`) |
| 7 | an unbounded field is left exactly as it was — the field inside a horizontal scroll view, the gutter at its full `GutterStyle.width` | widget (green on master; a regression guard on the fix) |

Tests 4, 5 and 7 are guards that are **green on master** and must stay green.
They are what stops the sweep being satisfied by a fix that narrows the gutter
— and, as it turned out, the code area — everywhere: test 4 reddened three
existing suites while the first attempt was in place.

No unit-test seam was needed. The defect is entirely in `Row` allocation, so
every behaviour is reachable through a real pumped `CodeField` — which is also
the only layout that can produce the overflow the bug is about.

## Why the sweep is not one width

A single 60 px case can be satisfied by a bound tuned to 60 px. Sweeping 44 to
320 px pins the invariant instead of the width: the gutter must never escape
the field at *any* width, and the framework's own overflow report is the
detector, so a width where it survives is not a pass.
