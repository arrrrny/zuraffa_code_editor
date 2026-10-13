# Spec: gutter-textstyle-alignment-150

Fork issue: #150 · Upstream: akvelon/flutter-code-editor#260
Label: `spec` · Severity: `low`

## What was asked

"Limit the variability of TextStyle in the gutter" — stop the gutter's line
numbers drifting away from the code lines when the host sets its own
`TextStyle`. Upstream's plan:

1. Inspect each `TextStyle` property and record whether a different value
   breaks alignment.
2. For every property that breaks it, take the value from `CodeField.textStyle`
   and force it in `GutterStyle.textStyle`.
3. Document which properties of `GutterStyle.textStyle` still have effect.

## What exists today

Steps 1 and 2 were already done, and not by this issue: `_buildGutter`
(`code_field.dart:787-798`) builds the gutter's style from the host's
`GutterStyle.textStyle` and then `copyWith`s the three metric properties from
`CodeField.textStyle` — `fontFamily`, `fontSize` and `height` — plus `color`
resolved through the host's own. The `height` line carries its own comment
("The gutter's line boxes must be exactly as tall as the code's") and was the
#43 fix.

So the behaviour this issue asks for is present. What is missing is step 3, and
a pin on steps 1-2:

- `GutterStyle.textStyle`'s dartdoc names only `fontSize` and `fontFamily` as
  ignored, omitting `height`, and never says which properties a host keeps.
- No test feeds a hostile `GutterStyle.textStyle` through the gutter alignment
  harness, so nothing distinguishes "the merge is complete" from "the merge
  drifted".

## The audit

`TextStyle` properties that set the height of a line box, and therefore have to
come from the code area:

| property | forced | why |
|---|---|---|
| `fontSize` | yes | with `height`, it is the line box height |
| `fontFamily` | yes | another face has different metrics |
| `height` | yes | the line-height multiplier itself |

Everything else a host may set freely — `color`, `fontWeight`, `fontStyle`,
`letterSpacing`, `wordSpacing`, `fontFeatures`, `fontVariations`,
`fontFamilyFallback`, `background`, `decoration`/`decorationColor`/
`decorationStyle`/`decorationThickness`, `foreground`, `shadows`, `debugLabel` —
because none of them changes where the row sits, only how the glyphs look.

## Acceptance

- [x] A property audit table: which `TextStyle` properties are forced from
      `CodeField.textStyle`, which are honoured — README + dartdoc.
- [x] A differing font size / font family / height in `GutterStyle.textStyle`
      cannot misalign the gutter — pinned by tests, each mutant killed.
- [x] The colour, weight and other non-metric properties stay overridable,
      with tests.
- [x] Public docs state which properties are overridden.
- [x] No regression: full suite green, `dart analyze --fatal-infos` clean,
      format clean, coverage gate at 100%.

## Non-goals

- Changing which properties are forced. Adding `fontFamilyFallback` to the
  forced set would be defensible on the same argument as `fontFamily`, but it is
  not what #260 names and it is a behaviour change, so it stays out of this
  issue.
- Gutter geometry beyond the line grid (column widths, icon sizing, padding) —
  those are `width`, `margin` and `padding` on `GutterStyle`, not `textStyle`.

