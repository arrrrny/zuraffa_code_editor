# Spec: auto-scroll-caret

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/42
(upstream akvelon/flutter-code-editor#316, still open there).

## Requirement

While the user types in a `CodeField`, the field must scroll the caret into
view once the text grows past the visible height, exactly like a plain
multiline `TextField`. The gutter must follow (the two scroll views are
linked), and horizontal scrolling behaviour must be unchanged.

## Acceptance

- A `CodeField` in a bounded-height host does not overflow its viewport
  when the text is longer than the viewport.
- After typing past the bottom edge, the field's vertical scroll offset is
  > 0 (the caret was revealed).
- No regression: full suite green, `dart analyze --fatal-infos` clean,
  format clean.

## Non-goals

- `expands: true` behaviour (already bounded by `Expanded`).
- Unbounded-height hosts (no viewport to scroll).
- A visible scrollbar — not requested by this issue.
