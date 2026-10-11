# Fix: keep every gutter row one code line tall (#107)

Closes #107 (upstream `akvelon/flutter-code-editor#312`, #215).

## What was wrong

The gutter lays its rows out in a `Table`, and a `Table`'s row height is the tallest cell in it. The number's `Text` is one code line tall, because `CodeField._buildGutter()` copies the code style's `height` onto the gutter style. But the two fixed icon columns always rendered their glyph at a hard-coded 16px:

- `gutter.dart` — `Icon(..., size: _issueColumnWidth)` (16.0)
- `fold_toggle.dart` — `Icon(Icons.chevron_right, size: 16)`

So whenever the code's line box was **shorter than 16px**, the icon was the tallest cell in every row it appeared in. The `Table` row was 16 tall, the row pitch exceeded the code line height by the overshoot, and the gutter separated from the code by that much again on every line below — the "progressively worse" symptom both upstream reports describe.

## Why the reported cases never showed it

Both upstream configurations, and every existing pin, use a line box of at least 16px:

| configuration | line box |
|---|---|
| upstream #312: `fontSize: 18, height: 1.5` | 27px |
| upstream #215: `fontSize: 16, height: 1.5` (gutter) | 24px |
| existing pin: `fontSize: 13, height: 1.6` | 20.8px |
| Material 3 default | 24px |

`gutter_alignment_test.dart` and `gutter_alignment_material3_test.dart` pin the row *pitch* at `closeTo(lineHeight, 0.001)` and pass on master today — they cannot detect a cell that is taller than the line box, because in their configurations no cell is.

## Measured on master (before)

`height: 1.0`, java source, default `GutterStyle`:

| fontSize | code lineH | pitch | drift at last row |
|---|---|---|---|
| 9 | 9.0 | 10.500 | 10.5px |
| 10 | 10.0 | 11.286 | 9.0px |
| 11 | 11.0 | 12.071 | 7.5px |
| 12 | 12.0 | 12.857 | 6.0px |
| 13 | 13.0 | 13.643 | 4.5px |
| 14 | 14.0 | 14.429 | 3.0px |
| 16 | 16.0 | 16.000 | 0.0px |
| 18 | 18.0 | 18.000 | 0.0px |

The **ablation is decisive**: the same sweep with `GutterStyle(showErrors: false, showFoldingHandles: false)` measures `delta = 0.000` at *every* font size, and the first row's top drops back to exactly `16.0` (the `codeFieldVerticalPadding` inset). The numbers themselves were already on the grid. The two icon columns are what moved them.

## The fix

`lib/src/gutter/gutter.dart`:

```dart
double get _iconSize =>
    math.min(math.max(_issueColumnWidth, _foldingColumnWidth), _rowHeight());
```

`_rowHeight()` measures the gutter's own resolved `style.textStyle` — the one `_buildGutter()` derives from the editor's style — so it tracks the code line height by construction, the same derivation the existing grid pins already rely on. `FoldToggle` grows an `iconSize` parameter so the chevron is clamped by the same figure.

## What is deliberately unchanged

- **The column widths**, and with them the gutter's geometry and the code's start offset. Only the glyph shrinks.
- **Rendering above a 16px line box**: `min(16, 24) = 16`, so `fontSize: 16, height: 1.5` renders the chevron at 16 exactly as before. `gutter_fold_toggle_test.dart`, `error_icon_override_test.dart` and `gutter_line_number_column_width_test.dart` are all green untouched.
- **`GutterStyle`** gains no new field — the clamp is derived, not configured.
- `GutterStyle.padding` (fork #6) and the `height` copy in `_buildGutter()` (upstream #262 / fork #28) — both already landed and pinned.

## Tests

`test/src/gutter/gutter_icon_row_height_test.dart` (new, 4 tests):

| test | red without the fix? |
|---|---|
| `13px line box: gutter rows stay one code line tall` | **yes** — `Expected: <30.5> Actual: <32.0>` |
| `sub-16 font sizes: gutter rows stay one code line tall` (9–18) | **yes** — `Expected: <28.5> Actual: <32.0>` |
| `every visible glyph is clamped to the code line height` | **yes** — `Expected: ≤13 Actual: 16` |
| `icons stay at 16 above a 16px line box` | no (characterisation, green on both trees) |

`32.0` is the pitch of two stacked 16px glyph boxes — the row was being sized by the icon column rather than the code line.

## Verification

- `flutter test` — **758/758 passing**
- `dart analyze` — clean; `dart format` — clean
- Coverage gate — **100.00% (3371/3371 over 105 files)**

One `tool/coverage_gate.py` exemption line number moves from `gutter.dart:230` to `gutter.dart:260`: the same dead `unfoldAt` lambda, exempted because the folded-block loop below overwrites that toggle before it can be tapped, shifted by the helpers inserted above it. The reason is unchanged.

Spec/assessment/TDD chain: `.specify/bugs/gutter-icon-row-height-107/`.
