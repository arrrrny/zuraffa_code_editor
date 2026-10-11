# Test List: gutter-icon-row-height-107

Derived from `.specify/bugs/gutter-icon-row-height-107/spec.md`.
Engine: `zfa tdd plan` unavailable (`ZFA_MISSING`, no `.zfa.json`) — this list
was derived by hand following the skill's fallback path.

## Fault-detecting tests (must be RED before the fix)

| # | Test | Detects |
|---|------|---------|
| 1 | `test/src/gutter/gutter_icon_row_height_test.dart` → `13px line box: gutter rows stay one code line tall` | row pitch exceeds the code line height (the #107 drift) |
| 2 | same file → `sub-16 font sizes: gutter rows stay one code line tall` (9,10,11,12,14,15) | the drift across the whole affected range |
| 3 | same file → `the fold-toggle chevron is clamped to the line height` | the 16px chevron inflating the row |
| 4 | same file → `icons stay at 16 above a 16px line box` | over-clamping: a regression that shrinks icons in the normal case |

## Characterisation tests (already GREEN — pin the unchanged paths)

| # | Test | Pins |
|---|------|------|
| 5 | `gutter_alignment_test.dart` (existing, 2 tests) | the `height`-copy layer at `fontSize: 13, height: 1.6` |
| 6 | `gutter_alignment_material3_test.dart` (existing, 3 tests) | same under Material 3 |
| 7 | `gutter_padding_test.dart` (existing) | `GutterStyle.padding` |
| 8 | existing `error_icon_override_test.dart` | the icon glyph/size on the override path, which mounts `GutterErrorWidget` directly and so is unaffected |

## Cycle log

See `cycle-log.md`.
