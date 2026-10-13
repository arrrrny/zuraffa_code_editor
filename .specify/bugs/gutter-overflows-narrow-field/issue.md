# Bug Issue: the gutter escapes the widget at narrow field widths

- **Slug**: gutter-overflows-narrow-field
- **Fetched**: 2026-10-13
- **Upstream**: `akvelon/flutter-code-editor#259` — "Line Numbers escape the
  widget"
- **Fork issue**: https://github.com/arrrrny/zuraffa_code_editor/issues/158
- **Severity**: low (a layout assertion; a field narrow enough to hit it is
  already near the edge of usability)

## Body

Upstream body verbatim:

```
![image](https://github.com/user-attachments/assets/6d684549-4d6b-41ac-9170-12ea9d3370e5)

Also, why is the line numbers side bar so... *wide?!*
```

## Full thread

One commenter's report of the same defect, which is the one half of this issue
that this fork had *not* already closed: a `CodeField` narrower than its own
gutter renders a gutter wider than the field, and the numbers paint outside the
widget's bounds.

## Prior art in this fork

The issue's stated root cause — the gutter's own scroll controller being
unlinked from the editor's — was closed here **verification-only, with no
source change** (fork issue #19, PR #58). The controllers come off one
`LinkedScrollControllerGroup`, and a regression test pins that they stay
together. The escape half of the report was left open by that closure.
