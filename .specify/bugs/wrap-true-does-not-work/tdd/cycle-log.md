# Cycle log: wrap-true-does-not-work

## Red

`test/src/code_field/wrap_true_test.dart` written against master `0d57280`:

```
Expected: a value less than or equal to <200>
  Actual: <2903.0>
```

Test 1 alone: `wrap: true` laid the line out 2903px wide inside a 200px box —
the flag was inert. Tests 2 and 4 passed on master (they pin the existing
unwrapped layout); test 3 failed on the extent comparison.

## Green

`_wrapInScrollView` now branches on `widget.wrap`: the wrapping path skips the
`IntrinsicWidth` and the horizontal `SingleChildScrollView` and bounds the
field by the editor box height, so `softWrap` (which `TextField` already
defaults to true) has a bounded width to reflow into.

Result: `flutter test test/src/code_field/wrap_true_test.dart` — 4/4 green.
Full suite 496/496 green; analyze and format clean.

## Red–green (gutter)

Wrapping exposed a second defect. A wrapped logical line occupies several
visual rows while the gutter's rows stayed one line high, so with 40 wrapped
lines the gutter's content was 11760px against the code's 13440px: the linked
scroll views clashed and the numbers froze while the code kept scrolling.

Fix: `GutterWidget` takes an optional `rowHeights` list, applied to every
cell through `_sized`; `_CodeFieldState` measures each visible line with a
`TextPainter` at the editor's own text width. `CodeLine.text` carries its
trailing newline, which made every line measure two rows — stripped first.
`rowHeights` is null unless `wrap` is set, so the unwrapped layout and all
its existing snapshots are unchanged.

Two iterations were needed on the width: the `LayoutBuilder` width overstates
the editor's text width by a few logical pixels of the field's own insets, so
the measurement can fall either side of a wrap boundary. The code field now
compares its measured rows against the editor's real scroll extent and, only
when they disagree, searches the adjacent widths — the gutter is a fixed
width, so this cannot feed back into the layout. Both a realistic field
(1890px = 1890px) and a deliberately narrow one (13440px = 13440px) match
exactly.

## Refactor

- `_withoutLineBreak` isolates the newline stripping instead of an inline
  `substring`.
- `_measureWrappedRows`, `_gutterRowExcess` and `_codePosition` split out so
  the fast path (heights already agreeing) reads in three lines and the
  calibration is confined to one block.
- The gutter's three fill methods each route their cell through `_sized`.
