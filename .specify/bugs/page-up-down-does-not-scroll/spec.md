# Spec: page-up-down-does-not-scroll

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/27
(upstream #195).

## Requirement

PageUp and PageDown scroll the editor by exactly one viewport, like any
other text field, with the gutter following.

## Acceptance

- 40 lines in a 200px field: `pageDown` moves the EditableText's
  Scrollable to ~200px, `pageUp` returns it to ~0.
- The scroll is clamped at the extents.
- Scrolls the editor's own scrollable (not the gutter's or the
  horizontal view's).

## Non-goals

- Moving the caret with the page keys (macOS TextField semantics) —
  the issue asks for scrolling only.
- Shift+PageUp/Down selection extension.
