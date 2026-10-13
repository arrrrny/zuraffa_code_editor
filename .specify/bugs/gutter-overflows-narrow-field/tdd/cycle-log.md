# Cycle log: gutter-overflows-narrow-field

## Red

`test/src/gutter/gutter_overflows_narrow_field_test.dart` written against
master `105d298` (no fix applied), verified by stashing the fix and re-running:

```
A RenderFlex overflowed by 28 pixels on the right.
  creator: Row ← Padding ← ColoredBox ← Container-[GlobalKey] ← Semantics …
  constraints: BoxConstraints(w=52.0, 0.0<=h<=600.0)
  size: Size(52.0, 600.0)
```

4 of the tests failed on the containment and sweep assertions. Measured at a
60 px field: the gutter rendered 378 → 458 inside a field ending at 430, and
the `TextField` laid out at 100 000 px. Controls — the same field inside a
horizontal scroll view, and the same at 400 px — behaved, confirming the
trigger is a row too narrow for the gutter rather than the gutter's own
geometry.

## Green, and the wrong instrument first

**Attempt 1 — a `LayoutBuilder` around the `Row` plus a
`ConstrainedBox(maxWidth:)` on the gutter.** Correct, and what eventually
shipped.

**Attempt 2 — `Flexible(flex: 1, fit: FlexFit.loose)`.** Passed all six of my
tests, and reddened three *existing* ones:
`horizontal_scrollbar_placement_test` ("a code area that cannot scroll shows
no thumb", "the vertical scrollbar is unaffected"),
`line_numbers_follow_scroll_test` ("the gutter keeps pace with the editor while
dragging") and `current_line_highlight_test`.

The cause is a Flutter rule worth writing down: **a flex allocation is not
handed back when a child takes less than it.** The gutter asking 80 px inside a
146 px share does not free those 66 px for its sibling; the `Expanded` code
area gets its own separate 146 px share. Measured at a 300 px field, the code
area was 146 px instead of the 212 px it should be. Narrow enough that
`int a = 1;` overflowed horizontally — so the scrollbar grew a thumb on a
document that fits — and narrow enough that a drag at x = 300 missed the code
area entirely, which is why the drag test's editor never scrolled.

So attempt 2 narrowed the code area at *every* field width, including the ones
that already worked. The regression suite caught what the new tests could not,
because the new tests had been written to pin the escape and not the code
area's width.

## What the loop changed in the design

- A seventh test was added: **the code area takes exactly the width the gutter
  leaves it.** It asserts `codeArea.width == field.width - 8 - gutter.width`,
  which a `Flexible` gutter fails. This is the invariant that makes the bound
  the right instrument rather than a share, and it was missing until the
  existing suite failed.
- The "escape" framing in the issue is accurate but incomplete: the escape is a
  *consequence* of the row overflowing, not a separate bug. Fixing the
  allocation fixes both, so there is one behaviour, not two.
- The reporter's aside that the sidebar is "so wide" was left alone.
  `GutterStyle.width` is a documented, configurable field and 80 px is its
  default; it is style taste, not what escapes the widget.
- One measurement gotcha, recorded so it is not repeated: the `Scrollable`
  *inside* the `TextField` is the horizontal scroller's **content**, not its
  viewport, and is wider than the box that clips it. The code area's viewport
  is the `SingleChildScrollView` that stands between the field and its editor.
