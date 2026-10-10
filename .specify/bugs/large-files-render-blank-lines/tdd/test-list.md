# TDD test list — #18 large files render blank lines

Status: **root cause measured; source change landed.**

| # | Test | Kind | State |
|---|------|------|-------|
| 1 | `the widest visible number fits on one line` | **fault-detecting** | green |
| 2 | `the gutter table is one code line tall per visible row` | **fault-detecting** | green |
| 3 | `the gutter scrolls as far as the code does` | **fault-detecting** | green |
| 4 | `the gutter stays the requested width while numbers fit` | backward-compat guard | green |

`test/src/gutter/gutter_line_number_column_width_test.dart`

All four read real layout out of a 1200-line `CodeField` at a fixed 400×528
viewport. The code line height is read back from the editor's own `EditableText`
style through `gutter_alignment_harness.dart`'s `renderedLineHeight`, so the
assertions follow the theme rather than assuming 24 px.

## Red → green

Red at `d3bdb1d` (before the gutter change), from
`flutter test test/src/gutter/gutter_line_number_column_width_test.dart`:

- test 1 — `Expected: a numeric value within <0.001> of <24.0> / Actual: <48.0>`
- test 2 — `Expected: a numeric value within <0.001> of <28824.0> / Actual: <55272.0>`
- test 3 — `Expected: a numeric value within <0.001> of <28328.0> / Actual: <54776.0>`
- test 4 — green (guard)

Green at the fix, and green across the whole suite (587 tests).
