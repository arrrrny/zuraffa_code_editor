# Data Model: per-line-background

The feature introduces no persistent state and no new entity. This document
records the shape of the one new value and the model it reads.

## New value

### `lineBackgroundBuilder` (on `CodeController`)

| Aspect | Value |
| --- | --- |
| Type | `Color? Function(int lineIndex)?` |
| Nullable | Yes — the null state is the default |
| Mutable | Yes, a plain field; reassign + `notifyListeners()` |
| Owner | `CodeController` (already a `TextEditingController`) |
| Visibility | Public (re-exported via `code_controller.dart`) |

**Input**: the index of a rendered line in the **full, unfolded** buffer —
0-based, the same coordinate space as `Issue.line`, `FoldableBlock.firstLine`
and the result of `HiddenLineRanges.recoverLineIndex(visibleLineIndex)`.

**Output**: the colour to tint that line's row with, or `null` for no tint.

**Validation**: none required. A `null` builder is the identity; a `null` result
per line is the identity for that line. An out-of-range index cannot reach the
hook because it is only called for lines that are rendered.

## Model the feature reads (all pre-existing)

| Source | Used for |
| --- | --- |
| `CodeController.code.lines` (`CodeLines`) | line count and per-line text |
| `code.lines[i].textRange` | character range, for the background layer's own measurement |
| `code.hiddenLineRanges.visibleLineNumbers` | the visible-line iteration order (the same list the gutter renders) |
| `code.hiddenLineRanges.recoverLineIndex(v)` | visible → full index mapping |
| `_wrappedRowHeights(textStyle)` (`_CodeFieldState`) | one height per visible line, incl. wrapped rows; already cached |
| `LinkedScrollControllerGroup` members | keeping the background layer aligned with the text |
| `CodeController.buildTextSpan` / `SpanBuilder` | where the full index is resolved authoritatively |

## State transitions

None. The hook is a pure function of line index, evaluated during render. No
transitions, no invalidation cache of its own beyond the row-height cache that
already exists.
