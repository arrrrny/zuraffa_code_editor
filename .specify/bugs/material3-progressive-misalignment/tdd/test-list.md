# TDD test list — #28 Material 3 gutter/code misalignment

Status: **verification only — no source change.** The fix is already on
`master` (commit `8d11ce7`).

| # | Test | Kind | State |
|---|------|------|-------|
| 1 | `Material 3: unfolded gutter shares the code line grid` | regression guard | green |
| 2 | `Material 3: folded gutter still shares the code line grid` | regression guard | green |
| 3 | `Material 3: a gutter style without height still lands on the code grid` | regression guard, **fault-detecting** | green |

File: `test/src/gutter/gutter_alignment_material3_test.dart`

## Red/green evidence

The provisional states were established by measuring real layout, not by
guessing:

- **Green (as shipped):** all three pass on `master` `7b3c3ef`.
- **Red (fault injected):** deleting only `height: textStyle.height,` from
  `CodeField._buildGutter()` fails test 3 with
  `gutter row pitch must equal the rendered code line height (24.0), was 23.0`
  — the 1 px/row progressive drift the issue reports.

## Why the existing tests did not cover this

`test/src/gutter/gutter_alignment_test.dart` already pins the same invariant
but always passes an explicit `textStyle: TextStyle(height: 1.6, ...)`. Since
`_buildGutter()` copies from `widget.gutterStyle.textStyle ?? textStyle`, and
`TextStyle.copyWith(height: null)` *preserves* the receiver's `height`, a
positive `height` on the editor style masks the bug: the gutter inherits
`1.6` whether or not the fix copies it across. Reaching the failing state
requires a `gutterStyle.textStyle` of the caller's own that omits `height`.
