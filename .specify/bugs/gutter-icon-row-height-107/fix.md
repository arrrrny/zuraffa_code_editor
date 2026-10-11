# Fix: gutter-icon-row-height-107

Status: **applied** — branch `bug/gutter-icon-row-height-107`, base master
`d12d537`.
Source assessment: ./assessment.md (issue #107).
TDD artifacts: ./tdd/test-list.md · ./tdd/cycle-log.md

## Changes

| File | Change |
|---|---|
| `lib/src/gutter/gutter.dart` | New `_iconSize` (clamped to the code line height) and `_rowHeight()`; the issue icon and both fold-toggle sites use `_iconSize` |
| `lib/src/gutter/fold_toggle.dart` | New `iconSize` parameter (default 16, so direct mounts are unchanged) |
| `test/src/gutter/gutter_icon_row_height_test.dart` | **new** — 4 tests: the 13px case, the sub-16 sweep, the clamp itself, and the ≥16 no-op |

## Deviations from the assessment

- The assessment proposed clamping the glyph to `math.min(max(16,16), rowHeight)`.
  Landed exactly that; the column widths are untouched, and the clamp reads the
  gutter's own resolved style, which `_buildGutter()` derives from the editor's,
  so it tracks the code line height by construction.

## Verification

- Red-checked: stashing the two `lib/` hunks makes the three fault-detecting
  tests fail (`Expected: <30.5> Actual: <32.0>`; `Expected: ≤13
  Actual: 16`) while the characterisation test stays green.
- `flutter test test/src/gutter/` — 53 tests, all passing.
- `flutter test` — 758 tests, all passing.
- `dart analyze` — clean; `dart format` — clean.
- Coverage gate — see ./test.md.


`lib/src/gutter/gutter.dart` lays the gutter out as a `Table`, and a `Table`'s
row height is the tallest cell in it. The number's `Text` is exactly one code
line tall, because `CodeField._buildGutter()` copies the code style's `height`
onto the gutter style. But the two fixed icon columns rendered their glyph at a
hard-coded 16px regardless of the code's line height:

- `gutter.dart:11-12` — `_issueColumnWidth` / `_foldingColumnWidth`, both 16.0
- `gutter.dart:205` — `Icon(..., size: _issueColumnWidth)`
- `fold_toggle.dart` — `Icon(Icons.chevron_right, size: 16)`

So whenever the code's line box was shorter than 16px, the icon was the tallest
cell in every row it appeared in. The `Table` row was 16 tall, the row pitch
exceeded the code line height by the overshoot, and the gutter separated from
the code by that much again on every line below it — the "progressively worse"
symptom both upstream reports describe.

## What changed

`lib/src/gutter/gutter.dart`:

```dart
double get _iconSize => math.min(
  math.max(_issueColumnWidth, _foldingColumnWidth),
  _rowHeight(),
);

double _rowHeight() {
  final style = this.style.textStyle;
  if (style == null) return _issueColumnWidth;
  final measured = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(text: '', style: style),
  )..layout();
  final height = measured.height;
  measured.dispose();
  return height > 0 ? height : _issueColumnWidth;
}
```

`_iconSize` is used for both the issue icon (`gutter.dart`) and the fold-toggle
chevron. `FoldToggle` grew an `iconSize` parameter (default 16, so direct
mounts are unchanged) so both columns are clamped by the same figure.

`_rowHeight()` measures the gutter's own resolved `style.textStyle` — the one
`_buildGutter()` derives from the editor's style — so it tracks the code line
height by construction, the same derivation the existing
`gutter_alignment_test.dart` pins already rely on. A null `textStyle` (a
`GutterWidget` built outside `_buildGutter()`) falls back to 16, matching
today's behaviour.

## What did not change

- The column widths, and therefore the gutter's geometry and the code's start
  offset. Only the glyph shrinks.
- Rendering above a 16px line box: `min(16, lineH)` is 16 there, so
  `fontSize: 16, height: 1.5` (24px) renders the chevron at 16 exactly as
  before.
- `GutterStyle` gained no new field — the clamp is derived, not configured.

## Measured effect (before → after)

`height: 1.0`, java source, default `GutterStyle`:

| fontSize | lineH | pitch before | pitch after |
| -------- | ----- | ------------ | ----------- |
| 9        | 9.0   | 10.500       | 9.000       |
| 10       | 10.0  | 11.286       | 10.000      |
| 13       | 13.0  | 13.643       | 13.000      |
| 14       | 14.0  | 14.429       | 14.000      |
| 16       | 16.0  | 16.000       | 16.000      |
| 18       | 18.0  | 18.000       | 18.000      |

Drift at the last row: 10.5px → 0.0px at fontSize 9, and 0.0 → 0.0 above the
boundary.

## Follow-ups

- The same "a cell taller than the line box inflates the row" failure mode
  could return with any new gutter column. The guard is now named
  (`_iconSize`), and `gutter_icon_row_height_test.dart` covers the sub-16
  range, so a new 16px-plus glyph in a fixed column will trip it.
- The `GutterStyle` doc on `textStyle` still says only colour is meaningful;
  with the clamp in place a caller can now set `fontSize`/`height` on it
  without desyncing the row, because `_buildGutter()` overrides them anyway.
