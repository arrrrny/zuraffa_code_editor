# #28 — Material 3 causes progressive misalignment between code and line numbers

- **Status:** verified already fixed on this fork; Material 3 guard tests added
- **Label:** `bug`
- **Source:** upstream `akvelon/flutter-code-editor#262`

## Reported symptom

With `theme: ThemeData(useMaterial3: true)` on `MaterialApp`, the line numbers
drift further and further away from the code they label. Under Material 2 the
same document is either aligned or *equally* misaligned (the sibling report,
upstream #261).

## The one theme value the editor reads

`CodeField` builds its code style from exactly one theme entry
(`lib/src/code_field/code_field.dart:500-507`):

```dart
final defaultTextStyle = TextStyle(
  color: styles?[rootKey]?.color ?? DefaultStyles.textColor,
  fontSize: themeData.textTheme.titleMedium?.fontSize,
  height: themeData.textTheme.titleMedium?.height,
);
```

`fontSize` and `height` together define the code's line box, so the line
numbers have to be laid out on the same box or the two grids diverge by the
difference on **every** row — which is what "progressive" means here.

## What this fork already has

`CodeField._buildGutter()` (`lib/src/code_field/code_field.dart:602-622`)
resolves the gutter style off the *same* object and copies the metric fields
across, `height` included:

```dart
final lineNumberTextStyle = (widget.gutterStyle.textStyle ?? textStyle)
    .copyWith(
      color: lineNumberColor,
      fontFamily: textStyle.fontFamily,
      fontSize: lineNumberSize,
      // The gutter's line boxes must be exactly as tall as the code's.
      height: textStyle.height,
    );
```

That landed in `8d11ce7` ("Fix folded comment gluing and gutter/chevron
line-height drift"), which fixed the folded-comment gluing and this drift in one
change. The comment in the source records the reason verbatim: without `height`
each gutter row falls back to the font's own metrics and so is a different
height than the text line it labels, and the two grids drift apart by that
difference on every line.

## How it was verified

`test/src/gutter/gutter_alignment_material3_test.dart`, three tests, all
measuring real layout rather than nominal values:

1. **unfolded, Material 3** — 37 rows, each asserted to sit at
   `textTop + i * lineHeight` where `lineHeight` is the height a `TextPainter`
   actually renders for the editor's style. A guard asserts
   `editable.style.height` is non-null, so the test cannot silently stop
   testing Material 3.
2. **folded, Material 3** — the same invariant after folding two methods.
3. **a caller-supplied `gutterStyle.textStyle` that omits `height`** — the case
   that actually detects a regression, because `_buildGutter` resolves its base
   style as `widget.gutterStyle.textStyle ?? textStyle` and a caller's style
   carries no `height` of its own.

### The test's fault-detecting power

Measured by deleting only the `height: textStyle.height,` line from
`_buildGutter()`:

```
M3 custom gutter style: gutter row pitch must equal the rendered code line
  height (24.0), was 23.0
```

One pixel per row — 37 px over the file, and unbounded as the file grows. That
is the reported symptom, and the existing
`test/src/gutter/gutter_alignment_test.dart` does **not** catch it because it
always passes an explicit `textStyle` with `height: 1.6`, which
`copyWith` preserves anyway.

## Conclusion

No source change is warranted: the fix is already on `master`. The Material 3
tests land as the guards the issue's specific reproduction always lacked —
`gutter_alignment_test.dart` never ran under `useMaterial3: true`, and never
exercised a caller-supplied gutter style.
