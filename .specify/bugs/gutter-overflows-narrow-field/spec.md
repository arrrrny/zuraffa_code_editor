# Spec: the gutter shares the row with the code area

## Why

Upstream #259 reports line numbers rendering outside the `CodeField`. The
scroll half of that report is already fixed here; the layout half is not. The
gutter and the editor share a `Row`, and the gutter was a plain child of it, so
the row laid it out at its own `GutterStyle.width` whatever the field had to
give. A field narrower than that gets a gutter wider than the field:

- the `Row` overflows and the framework reports it;
- the gutter's rendered rect runs past the field's own edge, which is the
  "escape" in the title — the numbers genuinely paint outside the widget;
- the code area, the `Expanded` child, gets the leftover and is laid out out of
  sight with it.

## Behaviours

| # | Behaviour |
|---|---|
| 1 | a `CodeField` narrower than its gutter renders no gutter rect past the field's bounds, in either axis, at a non-zero width |
| 2 | a `CodeField` narrower than its gutter renders every line-number rect inside the field |
| 3 | no field width from 44 px to 320 px raises a framework error or overflows the row |
| 4 | the code area takes exactly the width the gutter leaves it — the gutter's width is never sub-let into the code area's |
| 5 | a `CodeField` that can hold the gutter renders the gutter at `GutterStyle.width` exactly as before |
| 6 | a `GutterStyle(width:)` larger than the field is capped to the field rather than overflowing it, and still leaves the gutter non-zero |
| 7 | a `CodeField` inside an unbounded scroll view renders the gutter at its full `GutterStyle.width` and is otherwise unchanged |

## The rule

The gutter's advertised width is a *preference*, so the gutter is the party that
gives way. It is bounded to the width the row has, through a `LayoutBuilder`
around the `Row` and a `ConstrainedBox(maxWidth:)` on the gutter. It then takes
`style.width` when the row can give it, and the row's whole width when it
cannot.

**Bounding, not flex.** The gutter must stay a non-flex child. Two flex
children split the row between them, and a flex allocation is *not* handed back
when a child takes less than it: a `Flexible` gutter asking for 80 px inside a
146 px share would leave the `Expanded` code area with only that 146 px share,
66 px narrower than the 212 px the field has. So `Flexible` narrows the code
area at every field width — enough to break the horizontal scrollbar's
"nothing to scroll" case and the gutter-follows-editor drag. Behaviour 4 is the
test that pins this, and it is what makes a `Flexible` gutter ineligible.

## What this does not change

- The gutter's own width derivation (`style.width` → the fixed columns → the
  margin → the flex number column) is untouched. Every derived width follows,
  because it is computed from a width that is now bounded.
- A field wide enough to hold the gutter keeps it at `style.width`: the gutter
  is 80 px by default and stays so from ~168 px of field width upward. The
  shipped invariants in `gutter_line_number_column_width_test.dart` (80 px at
  the defaults, 64 with the folding column hidden) and the row-to-line grid
  alignment are unaffected — the cross axis is unchanged.
- Height, the row-to-line alignment (#107 / #215 / #312, shipped), the scroll
  linkage (#19, closed verification-only) and the row heights.

## Out of scope

`GutterStyle.width`'s own default of 80 px, and the reporter's aside that the
sidebar is "so wide". That is style taste and a documented, configurable field —
not a defect — and it is not what escapes the widget.
