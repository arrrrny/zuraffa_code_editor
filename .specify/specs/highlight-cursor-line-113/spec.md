# Spec: highlight-cursor-line

Fork issue: #113 · Upstream: akvelon/flutter-code-editor#194
Label: `spec` · Severity: `low`

## What was asked

"Highlight the line or line number that the cursor is on, similar to the way it
is done in VSCode."

## What exists today

Fork #86 landed `CodeController.lineBackgroundBuilder`
(`code_controller.dart:141-173`), which tints the background of individual
lines through `LineBackgroundLayer` (`lib/src/code_field/line_background.dart`):

- Called once per **visible** line with the line's 0-based index in the full,
  unfolded buffer — the same coordinate space as `FoldableBlock.firstLine` and
  `Issue.line`.
- The tint covers the full width of the line's row, not the extent of its text,
  and it sits behind the editor's search-match highlighting, which still wins on
  a matched run.
- Lines inside a folded block or a hidden section are not rendered, so the
  builder is not called for them.
- Left null, the layer is not in the tree at all: `code_field.dart:652-653`
  only wraps the editor in the `Stack` when the hook is set, so a field with no
  hook keeps its exact widget tree.

So every mechanism #194 asks for is already built and pinned by eleven tests in
`test/src/code_field/per_line_background_test.dart`. What is missing is that a
host has to write the follow-the-caret logic itself — and until now the one
example in the package that showed how was **wrong**:

```dart
controller.lineBackgroundBuilder = (line) =>
    line == controller.selection.base.offset ? Colors.yellow : null;
```

`line` is a **line index**; `controller.selection.base.offset` is a **character
offset**. The comparison is a category error: on the fixture document
`a\nbb\ncccc…\n`, a caret on the last line (offset 11) would tint line 11 — which
does not exist — while a caret at offset 1 tints line 1 by coincidence. The
example has to be corrected, and the natural correction is the feature this
spec delivers.

## What this spec adds

One nullable field on `CodeController`, beside `lineBackgroundBuilder`:

```dart
final Color? currentLineColor;
```

When non-null, the editor tints the row of the line the caret is on with it,
following the caret as it moves. The conversion from the caret's character
offset to a line index is done **by the editor**, using the helper that already
exists for it: `CodeLines.characterIndexToLineIndex`
(`lib/src/code/code_lines.dart:30`), the same conversion `Code` itself uses to
map a `TextRange` onto line numbers (`code.dart:382-383,487-488,524-525`).

The two hooks compose per line, and the explicit builder wins:

```dart
final color = lineBackgroundBuilder?.call(lineIndex) ??
    (lineIndex == caretLine ? currentLineColor : null);
```

So a host that already tints specific lines keeps that behaviour and gains a
cursor follower underneath it, and a host that sets only
`currentLineColor` gets VSCode's default `editor.renderLineHighlight: all`.

## Decisions

- **It is a row tint, not a gutter tint.** Upstream asks for "the line or line
  number". The row is what #86's layer already renders — full width, behind the
  text, scroll-linked, correct through wraps and folds. Adding a gutter tint
  means a second, independent paint path inside `_buildGutter`
  (`code_field.dart:722`+) with its own geometry, and buys a visual variant
  rather than a capability. This spec takes the row; a gutter variant is a
  separate issue.
- **The caret, not the anchor.** The highlighted line is the line of
  `selection.extentOffset` — the end that moves, which is the caret after a
  click, a drag, or a shift-arrow. With `selection.baseOffset` a shift-arrow
  from line 5 down to line 10 would highlight line 5, the anchor, while VSCode
  highlights line 10. For a collapsed caret — the common case — the two are
  equal, so the choice only matters for a range, and `extent` is the one that
  matches the reference behaviour. This is called out in the doc comment.
- **Only the caret's line for a range.** VSCode tints the single line holding
  the caret, not the whole selection. Same here.
- **Null default, like the hook it builds on.** A non-null default would tint
  every existing user's editor and change the default widget tree, and #86
  deliberately established "left null, the editor renders exactly as it does
  without this field". Opt-in keeps that invariant and keeps the existing
  test `leaves the field untouched when it is not set` meaningful.
- **No second widget, no second scroll controller.** `LineBackgroundLayer`
  already exists and already handles the hard parts (visible-line iteration,
  row heights, gutter padding). Widening its gate and its colour resolution is a
  few lines; a parallel `CurrentLineLayer` would duplicate all of that and would
  have to be told which of the two layers is "behind" the other.
- **The offset→line conversion reuses `characterIndexToLineIndex` rather than
  adding a helper.** It is the package's own binary search over
  `CodeLine.textRange`, it is already what `Code` uses to map a `TextRange` to
  line numbers, and it throws `RangeError` outside `[0, text.length]` — which is
  why the index is computed once, behind a guard, instead of per row.
- **Guard, do not trust.** `selection.extentOffset` is `-1` on a
  `TextEditingValue` with no selection (`text_editing_value.dart:172-203`
  clamps both offsets, but only for values that pass its `-1` checks) and can
  exceed the length of `controller.code.text` while `code` is being rebuilt. The
  conversion is therefore range-checked against the current `code.text.length`
  and skipped entirely when the caret is out of range. A tint that throws inside
  `build` takes the whole editor down.
- **A caret on a hidden line paints nothing.** If the caret's line is inside a
  folded block or a hidden section, that line is not rendered, so there is no row
  to tint. That is the same rule #86 already documents for the builder, and it
  is asserted rather than special-cased.

## Out of scope

- Tinting the gutter / line number as well (see Decisions — a separate issue).
- A `renderLineHighlight` enum with a `gutter` variant.
- A themed default colour, or reading `ThemeData` for one: #86 set the
  precedent that a null default keeps the tree unchanged, and a themed default
  is a breaking visual change for every existing host.
- Animating the tint between lines.
- Any change to `lineBackgroundBuilder`'s signature or to the other eleven
  per-line-background tests, which must pass **unmodified** as the regression
  net for this change.

## Acceptance criteria

- [ ] `CodeController` accepts `currentLineColor`, `Color?`, default null.
- [ ] With it set and `lineBackgroundBuilder` null, the caret's row is tinted
      with it, across the full row width, behind the text.
- [ ] The tint follows the caret: moving the caret with a keystroke, a tap, and
      a shift-arrow moves the tint to the new caret line.
- [ ] A selection spanning several lines tints only the caret's line.
- [ ] A caret inside a folded block or a hidden section tints nothing.
- [ ] A field with neither hook set renders the same widget tree as before this
      change — no `Stack`, no `LineBackgroundLayer`.
- [ ] With both hooks set, the host builder's colour wins on the lines it
      colours, and `currentLineColor` still tints the caret's line when the
      builder returns null for it.
- [ ] The wrong doc example on `lineBackgroundBuilder` (line index compared
      against a character offset) is corrected, and the corrected form either
      uses the conversion or points at `currentLineColor`.
- [ ] No caret state crashes the build: an empty document, a `TextEditingValue`
      with no selection (`extentOffset == -1`), and a caret at the very end of
      the text all render.
- [ ] The eleven existing tests in
      `test/src/code_field/per_line_background_test.dart` pass unmodified.
- [ ] Coverage stays at the 100% gate; every new branch is covered or proved
      dead.

## Gates

`flutter test --concurrency=2` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
