# Cycle log: auto-scroll-caret

## Red

`test/src/code_field/auto_scroll_caret_test.dart` written against master
`ff02b3b` (no fix applied):

```
A RenderFlex overflowed by 792 pixels on the bottom.
Expected: a value greater than <0>
```

Two failures reported — the overflow and the scroll assertion.

## Green

Fix: `_wrapInScrollView` receives `constraints.maxHeight` and bounds the
field with `ConstrainedBox(maxHeight: maxHeight)`; the field's internal
vertical scrollable (`_codeScroll`, linked to the gutter) then owns the
scrolling and Flutter's caret auto-reveal applies.

Result: `flutter test test/src/code_field/auto_scroll_caret_test.dart` —
all passing. Full suite 424/424 green; analyze and format clean.

## Refactor

- Bound only the non-`expands` path; the `expands` path already scrolls via
  `Expanded`.
- Comment in `code_field.dart` records why the bound is needed.
