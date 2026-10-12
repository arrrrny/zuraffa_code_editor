# Contract: `currentLineColor`

The public surface this spec adds, and the exact behaviour a host can rely on.
Everything not listed here is unchanged.

## The field

```dart
// lib/src/code_field/code_controller.dart, beside lineBackgroundBuilder
final Color? currentLineColor;
```

Nullable, defaults to `null`, public and mutable at runtime. Setting it does not
require `notifyListeners()` for the next keystroke to pick it up — the layer reads
it during `build`, and #86 already pins (`per_line_background_test.dart:237`) that
reassigning a hook plus `notifyListeners()` re-renders. The same applies here; the
test is repeated for this field.

## Resolution rule

For each **visible** line, in `Code.hiddenLineRanges.visibleLineNumbers` order
(`line_background.dart:45`):

```dart
final color = lineBackgroundBuilder?.call(lineIndex) ??
    (lineIndex == currentLineIndex ? currentLineColor : null);
```

- The host's `lineBackgroundBuilder` is consulted **first** and its answer is
  final. It is never called by the caret logic, and the caret never overrides it.
- `currentLineColor` only applies to the single line holding the caret.
- `null` from either means "no tint on this row" — a `SizedBox`, not a
  transparent `Container`, so an untinted row still reserves its height.

## Which line holds the caret

`selection.extentOffset` — the end that moves, i.e. the caret after a click, a
drag, or a shift-arrow. For a collapsed caret (the common case) `base` and
`extent` are equal and the choice is invisible.

Converted once per build with `CodeLines.characterIndexToLineIndex`
(`code_lines.dart:30`), behind this guard:

```dart
final text = controller.code.text;
final offset = controller.selection.extentOffset;
final currentLineIndex = offset >= 0 && offset <= text.length
    ? controller.code.lines.characterIndexToLineIndex(offset)
    : -1;
```

**Guarantees that follow:**

- A caret at `text.length` — the end of the document — is a valid index and
  tints the last line. It is not rejected.
- `extentOffset == -1` (the no-selection sentinel this repo already handles
  throughout `text_editing_value.dart:172-203`) tiles nothing.
- A caret whose offset is beyond the current `code` text — reachable for one
  frame while `code` catches up with a text change — tiles nothing.
- `characterIndexToLineIndex` never throws inside `build`, because the guard
  keeps every call inside its documented `[0, text.length]` domain. A
  `RangeError` from a `build` method takes the whole editor with it, which is the
  reason this guard exists rather than a bare call.
- `-1` can never equal a visible line number, so the "no caret" case needs no
  extra branch downstream.

## What it does not do

- It does not tint the gutter or the line number. Upstream asked for "the line or
  line number"; this takes the row, which is what #86's layer already renders
  correctly. A gutter variant is a separate issue.
- It does not tint every line of a multi-line selection — only the caret's line,
  matching VSCode.
- It does not tint a line that is inside a folded block or a hidden section,
  because such a line is not rendered and the layer never asks about it. If the
  caret is on a hidden line, nothing is tinted. No special case, no crash.
- It does not change `lineBackgroundBuilder`'s signature, its call order, or the
  coordinate space (0-based index in the full, unfolded buffer).
- It does not export anything new. `LineBackgroundLayer` stays `@internal` and
  out of the barrel.

## Tree-shape guarantee

The `Stack` and the `LineBackgroundLayer` enter the tree when **either** hook is
set, and only then:

```dart
// lib/src/code_field/code_field.dart, ~652
child: widget.controller.lineBackgroundBuilder == null &&
        widget.controller.currentLineColor == null
    ? editingText
    : Stack(children: [Positioned.fill(child: ... LineBackgroundLayer ...), editingText]),
```

A field with both hooks null renders exactly the tree it renders today. This is
the invariant #86's test `leaves the field untouched when it is not set` pins,
and it must keep passing unmodified.

## The doc example to correct

`code_controller.dart:169-170` currently reads:

```dart
controller.lineBackgroundBuilder = (line) =>
    line == controller.selection.base.offset ? Colors.yellow : null;
```

`line` is a line index; `selection.base.offset` is a character offset. This is
wrong and would mislead anyone reaching for the follow-the-cursor case. It is
replaced with a working conversion using this spec's own field:

```dart
controller.currentLineColor = Colors.yellow.withValues(alpha: 0.1);
```

plus, if an explicit conversion is still shown for the builder, one that goes
through `characterIndexToLineIndex` against `selection.extentOffset`. The
corrected example must be verified by a test that compiles and asserts the tint
lands on the caret's line — a doc example nobody ran is how the wrong one got
in.

## Gates

`flutter test --concurrency=2` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
