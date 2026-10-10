# Spec: wrap-true-does-not-work

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/9
(upstream akvelon/flutter-code-editor#285, with #221 and #191 open there;
upstream never wired the flag either).

## Requirement

`CodeField.wrap: true` must soft-wrap long lines into the field's width
instead of scrolling them horizontally. Today the flag is stored and never
read: `_wrapInScrollView` always sizes the field to its longest line via an
`IntrinsicWidth` inside a horizontal scroll view, so the text never reflows
whatever the flag says.

## Acceptance

- With `wrap: true` the editor stays within its viewport width and a long
  line occupies several visual rows.
- With `wrap: false` (the default) the field still grows past its viewport
  and scrolls horizontally — the existing behaviour is untouched.
- The gutter still tracks the code: with wrapping, a logical line spans
  several visual rows, so the gutter's rows must be as tall as the code
  renders them or the two scroll views disagree about the content length and
  the numbers drift off their lines.
- No regression: full suite green, `dart analyze --fatal-infos` clean,
  format clean.

## Non-goals

- Word-wrap-aware line numbers in the sense of per-visual-row numbers — the
  gutter stays one number per logical line, sized to that line's wrapped
  height.
- Horizontal scrolling combined with wrapping (mutually exclusive by
  design here).
- Making `wrap` the default.
