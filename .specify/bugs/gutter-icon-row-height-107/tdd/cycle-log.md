# Cycle Log: gutter-icon-row-height-107

Engine: `zfa tdd run` unavailable (`ZFA_MISSING`, no `.zfa.json`) — this cycle
was driven by hand following the skill's fallback path.

## Red

Stashed the `lib/` changes and ran
`flutter test test/src/gutter/gutter_icon_row_height_test.dart` against the
unfixed tree (`d12d537`, master with #126 and #127 merged):

```
13px line box: gutter rows stay one code line tall [E]
  Expected: a numeric value within <0.001> of <30.5>
  Actual: <32.0>

sub-16 font sizes: gutter rows stay one code line tall [E]
  Expected: a numeric value within <0.001> of <28.5>
  Actual: <32.0>
  fontSize 9.0: gutter row 1 is off the code grid (line height 9.0)

every visible glyph is clamped to the code line height [E]
  Expected: a value less than or equal to <13.0>
  Actual: <16.0>

icons stay at 16 above a 16px line box  <- GREEN
```

`32.0` is the smoking gun: the row pitch equals `16 + 16` exactly, i.e. two
16px glyph boxes stacked, because the row was sized by the icon column rather
than by the code line. The 4th test is the characterisation guard and passes as
expected — the fix must not touch the ≥16 case.

## Green

Applied the fix in `lib/` (see `fix.md`), re-ran the same file:

```
All tests passed! (4 tests)
```

## Verification of the invariant

Full `flutter test` on the branch, plus `dart analyze` and `dart format`.
See `test.md` for the run output and the coverage gate result.

## What the existing pins did and did not cover

`gutter_alignment_test.dart` (2 tests) and `gutter_alignment_material3_test.dart`
(3 tests) pin the row *pitch* against the rendered line height, but only at
configurations whose line box is ≥16px (`fontSize: 13, height: 1.6` → 20.8px;
the Material 3 default → 24px). Both stayed green on the unfixed tree — they
cannot detect a cell that is taller than the line box, because in their
configurations no cell is. The four tests here cover the sub-16 range that
reaches the fault.
