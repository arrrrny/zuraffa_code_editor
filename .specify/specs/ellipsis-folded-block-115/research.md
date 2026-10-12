# Research: ellipsis-folded-block

Fork issue #115 / upstream #86 ("Ellipsis for folded block", body empty).
Classification: `spec`, `low`, backlog rank 18.

The issue is one line — "Render an ellipsis or chevron on the folded line so
hidden content is visible" — with "Where it lives: `gutter render`". That
brevity hides three decisions, each of which is recorded here with the evidence.

## R1 — is a chevron already rendered?

**Question.** The issue offers "ellipsis **or** chevron". If a chevron is already
rendered, part of the ask is already met and the spec should say so rather than
build a second indicator of the same thing.

**Finding.** Yes. `FoldToggle` (`lib/src/gutter/fold_toggle.dart`) renders in the
gutter's folding column for every `code.foldableBlocks` entry, and its glyph is a
`RotatedBox` of `Icons.chevron_right` — one quarter-turn when unfolded, none when
folded. `GutterWidget._fillFoldToggles` (`gutter.dart:253-292`) places it on the
row of `block.firstLine`, and a second loop re-hangs the toggle for blocks that
were folded and have since become invalid. `iconSize` is clamped to the code
line's height so a short line box cannot drift the rows below it (#107).

So foldedness is already visible in the gutter, and clicking the chevron unfolds.
**The spec must not duplicate that.** What the issue still asks for is an ellipsis
marking *where the hidden content begins*, which no existing affordance does.

## R2 — where does a fold leave the text, and what line stays on screen?

**Question.** "The folded line" is ambiguous. A fold over lines 0–2 could keep
line 0, or the closer, or a new placeholder row. The marker's position depends
entirely on this.

**Finding.** `Code.foldableBlockToHiddenRange` (`code.dart:636-680`) builds the
hidden range from `firstLine = lines.lines[block.firstLine + 1]`, with the comment
"Keep 1st line visible". The range starts at `firstLine.textRange.start - 1` (the
newline before it) and ends at:

- the **start** of `block.lastLine` when that line is a closing line (`)`, `]`,
  `}`), so the closer stays on screen — the alternative hid the closer and made
  `parsers: [` fold to a lone opening bracket, which reads as broken code;
- `_upstreamEndOfRange(lastLine)` (its end) for a content line, because stopping
  at its start would delete only the preceding newline and glue the content
  onto the line above: `// first// second`.

And when the closer also opens the following block (`}void main(){`, upstream
#213), the range ends just before it so the closer gets a row of its own.

So after a fold of a block whose opener is line 0:

- **line 0's text is on screen**, ending where the fold begins;
- lines 1…n-1 are gone;
- **the closer (line n) is on screen**, on its own row when it has to be.

**Decision.** The marker belongs at the **end of the kept line's text**, i.e.
immediately after the last visible character of `block.firstLine`. That is the
point where content disappeared, it is where VSCode puts its ellipsis, and it is
the only position that reads as "more, here".

## R3 — the constraint that rules out the obvious implementation

**Question.** Can the marker simply be appended to the text, the way a host would
expect?

**Finding.** No, and this is the load-bearing constraint of the whole issue.
`HiddenRanges.cutString` (`hidden_ranges.dart:66`) cuts the hidden ranges out of
the full text, and the result is `Code.visibleText` (`code.dart:153`), which
becomes the `TextEditingController`'s value (`code.dart:434`). The visible text
is therefore **the editing buffer**, not a rendered projection of it:
`cutSelection`/`recoverSelection` (`hidden_ranges.dart:324-352`) map the caret and
every selection through the same ranges, `Code.getEditResult` replays an edit of
the visible text against the full text, and `LineNumberingBreakpoint` numbering
is derived from the same offsets. Putting an ellipsis into that string would:

- shift every offset after it by one character, so a caret placed by tapping
  lands one character off from where the user tapped;
- make the ellipsis selectable, deletable and typeable-over, which is exactly
  wrong for a synthetic marker;
- and, because `foldableBlockToHiddenRange`'s comment notes the offsets are
  resolved through `characterIndexToLineIndex` to build the line numbering,
  corrupt the gutter's numbering for every folded document.

**Decision.** The marker must be **painted only**. No character may enter
`visibleText`, and no offset may move.

## R4 — the two ways to paint it, and which one this spec takes

### Option A: append to the span tree (recommended)

`CodeController.buildTextSpan` (`code_controller.dart:1300-1310`) delegates to
`_createTextSpan` → `SpanBuilder.build()`, which walks
`code.visibleHighlighted.nodes` and already maintains `_visibleLineIndex` while
it goes (`span_builder.dart:74-80`). Appending a `TextSpan(text: ' …')` to the
node that ends the kept line paints the ellipsis exactly where it belongs, at
whatever offset and baseline the line's own text renders at, with no measurement
and no coordinate work. It is one splice in one place that already tracks the
line index.

The known cost: the rendered span is then longer than `value.text`, so the
ellipsis occupies a region `RenderEditable` will hit-test into the caret offsets
that follow it. Offsets are derived from `value.text`, so the caret clamps to the
end of the real text and the ellipsis is never *selected* — but a caret parked on
that line renders to the right of the ellipsis rather than to its left. That is a
cosmetic cost on a marker whose whole job is to be seen, and it is testable.

**This is what the spec takes.** The alternative geometries are rejected below
with reasons, and `tasks.md` carries a test that `controller.text` is byte-for-byte
unchanged by a fold, which is the assertion that keeps Option A honest.

### Option B: a paint-only overlay layer

Precedent is `LineBackgroundLayer` (#86), and it would keep the span tree and the
editing model untouched. But it needs the ellipsis's x to be the **end of the
line's text**, and the only two ways to know that are:

- measure the line's text with a `TextPainter`, which must then match the
  rendering exactly — same style, same letter spacing, same wrapping — for a
  line whose spans are highlighted per token and which may wrap across several
  rows; or
- ask the editor's own `RenderEditable.getLocalRectForCaret` for the position,
  which is authoritative but requires converting between the editable's
  coordinate space and the overlay's, with an independently-scrolling
  `SingleChildScrollView` in between (`code_field.dart:657-665`).

Both are strictly more machinery than Option A for the same visual, and both
introduce a way to drift from the text.

### Option C: a fourth gutter column

Rejected on cost, not correctness. `GutterWidget` builds a three-column `Table`
(`gutter.dart:114-122`): a flex line-number column, a fixed issue column and a
fixed 16px folding column, with the container width computed as their sum plus
`style.margin` (`gutter.dart:106-113`). A fourth column changes that sum, so
**the gutter would get wider for every field, folded or not**, shifting the
editor's text x offset — a layout change every host sees, to serve documents
that have no folds. (Narrowing an existing column was already rejected once, for
the same reason: `gutter.dart:163-174` documents #107 there.)

The alternative of squeezing the ellipsis into the existing folding column
would put it beside or under the chevron, which is the duplicate affordance R1
rules out.

## Summary of decisions

| Decision | Answer |
| -------- | ------ |
| Does the chevron already answer the issue? | Yes, for foldedness; no ellipsis exists |
| Which line does the marker sit on? | The kept `firstLine`, at the end of its text |
| Can the marker enter the text? | No — `visibleText` is the editing buffer |
| How is it painted? | Appended to the span tree, in `SpanBuilder` |
| Fourth gutter column? | Rejected — changes layout for every host |
