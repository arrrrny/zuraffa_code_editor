# Cycle log: page-up-down-does-not-scroll

## Red

Reverting only `code_field.dart` (intent/action files present):
`Expected: a numeric value within <1> of <200>` / `Actual: <96.0>` — the
app-level ScrollIntent answering instead, scrolling the wrong scrollable.

## Green

PageUp/Down bound to `PageScrollIntent` in the field's shortcut map;
`PageScrollAction` (wired by the state with `_codeScroll`) animates the
editor's own scrollable by one editor-box height. Test passes:
exactly 200 down, exactly 0 back up.

## Refactor

- Action takes `ScrollController?` + `pageHeight` provider so the state
  can supply the scroll controller that lives on the view side.
- Animated (150ms, easeOut) rather than jumping; tests settle it.
