# Bug Assessment: Gutter numbers and code text are not vertically aligned

- **Slug**: gutter-icon-row-height-107
- **Created**: 2026-10-11
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/107
- **Verdict**: **valid, reproduced, root-caused and fixed.**
- **Severity**: medium

## Symptom as filed

A visible vertical drift between the gutter numbers and the code column. Two
upstream reports, both with the same observable: the gutter and the code are on
the same grid at the top and separate progressively as you go down.

## Why the reported cases hide the mechanism

Both upstream reporters and every existing pin use a code line box **at least
16px tall**:

- `fontSize: 16, height: 1.5` → 24px
- `fontSize: 18, height: 1.5` → 27px
- the existing pins' `fontSize: 13, height: 1.6` → 20.8px

So the drift they see is not the `height`-copy layer — that was fixed upstream
by #320 and here by commit 8d11ce7, and `gutter_alignment_test.dart` /
`gutter_alignment_material3_test.dart` pin it at `closeTo(lineHeight, 0.001)`.
Those tests pass on master today. What they cannot see is a second, independent
source of drift that only bites when the line box is **shorter than 16px**.

## Reproduction

```dart
CodeField(
  controller: CodeController(text: src, language: java),
  textStyle: const TextStyle(fontSize: 13, height: 1.0), // 13px line box
)
```

Default `GutterStyle` (folding handles and error icons on). Measure each gutter
number's rect against the code line grid.

## Measurement (master, before the fix)

`fontSize`, `height: 1.0`, java source, default gutter:

| fontSize | code lineH | measured pitch | delta/row | drift at line 8 |
| -------- | ---------- | -------------- | --------- | --------------- |
| 9        | 9.0        | 10.500         | +1.500    | 10.5px          |
| 10       | 10.0       | 11.286         | +1.286    | 9.0px           |
| 11       | 11.0       | 12.071         | +1.071    | 7.5px           |
| 12       | 12.0       | 12.857         | +0.857    | 6.0px           |
| 13       | 13.0       | 13.643         | +0.643    | 4.5px           |
| 14       | 14.0       | 14.429         | +0.429    | 3.0px           |
| 16       | 16.0       | 16.000         | 0.000     | 0.0px           |
| 18       | 18.0       | 18.000         | 0.000     | 0.0px           |

The **ablation is decisive**: the same sweep with
`GutterStyle(showErrors: false, showFoldingHandles: false)` measures
`delta = 0.000` at **every** font size, and `firstTop` drops back to exactly
`16.0` (the `codeFieldVerticalPadding` inset). The numbers themselves are
already on the grid. The two icon columns are what move them.

## Root cause

`lib/src/gutter/gutter.dart` builds the gutter as a `Table` whose row height is
the tallest cell in it. The number `Text` is exactly one code line tall — that
is the `height` copy in `_buildGutter()`. But the two fixed icon columns are
hard-coded to 16 and always render a glyph at that size:

- `gutter.dart:205` — `Icon(..., size: _issueColumnWidth)` (16.0)
- `gutter.dart:11-12` — `_issueColumnWidth` / `_foldingColumnWidth` (16.0 each)
- `fold_toggle.dart` — `Icon(Icons.chevron_right, size: 16)`

So whenever the code line box is shorter than 16px, the icon is the tallest cell
in every row it appears in, the `Table` row is 16 tall, and the row pitch
exceeds the code line height by the overshoot. Because the pitch error applies
once per row, the gutter separates from the code linearly down the file — the
"progressively worse" symptom both upstream reports describe, and exactly what
upstream #312 means by "otherwise is 4 units misaligned" (their `fontSize: 18`
case is near the boundary; their reporter's own font metrics push it over).

The `_widestNumberWidth` measurement and the `numberColumnWidth` `math.max`
already exist to stop a cell from inflating a row (the #18 desync). The icon
columns had no equivalent guard.

## Proposed remediation

Clamp the icon glyph to the code line height, keeping the column widths
untouched so the gutter's geometry — and the code's start offset — is
byte-identical:

```dart
double get _iconSize => math.min(
  math.max(_issueColumnWidth, _foldingColumnWidth),
  _rowHeight(),
);
```

`FoldToggle` grows an `iconSize` parameter so the chevron is clamped by the same
figure. Above a 16px line box the clamp is a no-op: `min(16, 24) = 16`, so
every existing rendering is unchanged and every existing test stays green.

## Risks & Considerations

- Only the glyph shrinks, and only when the code line is shorter than 16px.
  A 9px line box gets a 9px chevron — the right trade: the gutter's whole job
  is to stay on the code's grid.
- The clamp reads the *gutter's own* resolved `style.textStyle`, which
  `_buildGutter()` derives from the editor's style, so it tracks the code line
  height by construction (same derivation the existing pins rely on).
- `style.textStyle` is null only for a `GutterWidget` built outside
  `_buildGutter()`; the fallback keeps 16 there, matching today's behaviour.

## Non-goals

- `GutterStyle.padding` (fork #6) and the `height` copy (upstream #262 / fork
  #28) — both already done and pinned.
- The wrap-mode `rowHeights` path, which is separately measured and pinned.
