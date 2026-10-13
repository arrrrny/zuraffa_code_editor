# Bug Assessment: the gutter escapes the widget at narrow field widths

- **Slug**: gutter-overflows-narrow-field
- **Created**: 2026-10-13
- **Source**: upstream `akvelon/flutter-code-editor#259` (synced from the fork's
  own issue #19, which was closed verification-only for the scroll half)
- **Verdict**: valid — the escape half of the report is real and was never fixed
- **Severity**: low (needs a field narrower than the gutter; but it is a
  framework assertion, not a cosmetic one)

## Symptom

A `CodeField` narrower than its gutter renders a gutter wider than the field:

- the `Row` holding the gutter and the code area overflows and reports
  `A RenderFlex overflowed by N pixels`;
- the gutter's rendered rect runs past the field's own right edge — the
  "escape" in the issue title, the numbers genuinely painting outside the
  widget;
- the code area, the `Expanded` child of that row, gets the leftover and is
  laid out out of sight with it.

Measured on master at a 60 px field: the gutter renders 378 → 458 inside a
field ending at 430, and the `TextField` is laid out at 100 000 px wide.

The reporter's own workaround — the field inside a horizontal scroll view —
works, because the row then has an unbounded width to give and nothing
overflows.

## Root cause

`CodeField.build` puts the gutter and the editor in a `Row`
(`lib/src/code_field/code_field.dart:948`). A `Row` lays out its **non-flex**
children at their own requested size, bounded only by the space *remaining
after* them is allocated to flex children — so the gutter, a plain child, was
laid out at its full `GutterStyle.width` (80 px by default) whatever the field
had. `GutterWidget` honours that width literally: its `Container` is
`width: issueColumn + foldingColumn + margin + numberColumnWidth`
(`lib/src/gutter/gutter.dart:106-113`).

So when the row has less than the gutter wants, the gutter keeps its width, the
`Expanded` code area gets a negative or zero remainder, and the row overflows.
Nothing in the existing geometry knew how to yield, because nothing was asked
to: the gutter's width derivation is entirely `style.width`-relative and never
looks at the field.

## Reproduction

Widget test, `test/src/gutter/gutter_overflows_narrow_field_test.dart`:

1. Pump `MaterialApp > Scaffold > SizedBox(width: 60) > CodeField` with the
   default `GutterStyle`.
2. Compare `tester.getRect(find.byType(GutterWidget))` with
   `tester.getRect(find.byType(CodeField))`.

On master this **fails**: the gutter's right edge is 28 px past the field's,
with `A RenderFlex overflowed by 28 pixels` from the framework.

## Scope

The **width** geometry only. Height, the row-to-line alignment (#107 / #215 /
#312, all shipped) and the scroll linkage (#19, closed verification-only) are
separate and already pinned.
