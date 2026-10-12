# Data model: ellipsis-folded-block

No new types, no new exported state, no new public API. The spec adds two
private derived values and one private constant inside `SpanBuilder`, one extra
leaf `TextSpan` in the tree it returns, and one internal flag threaded from
`CodeController`. Two files change under `lib/`. Everything else the feature
touches already exists and is unchanged.

## New state

None that is visible. A marker that had to be remembered would have to live on
the controller, which would make it part of the widget's public surface and would
invite a setter. `SpanBuilder` is constructed per `_createTextSpan` call
(`code_controller.dart:1384-1391`), so the derivation is per build and dies with
the span.

## New derived values

| Name | Type | Where computed | Domain |
|---|---|---|---|
| `_foldedKeptLines` | `Set<int>` | `SpanBuilder.build`, from `code.foldedBlocks` | Visible line indices that are the kept first line of a folded block |
| `_treeEndsWithNewline` | `bool` | `SpanBuilder._updateLineIndex`, per node | Whether the last node with text ends in `'\n'` |
| `_foldEllipsis` | `const String` | top of `span_builder.dart:25` | The marker, `' …'` |

`_foldedKeptLines` is derived once per build, from the same `code` the rest of
the walk reads, so it cannot disagree with the tree it is applied to. The
derivation is `code.hiddenLineRanges.cutLineIndexIfVisible(block.firstLine)` for
each entry in `code.foldedBlocks`, discarding the nulls — and the null branch is
*reachable* and *correct*, not defensive: see "The nested-fold branch" below.
Because `cutLineIndexIfVisible` is the inverse of the map the walk already uses
(`recoverLineIndex`, `hidden_line_ranges.dart:69-71`), the two cannot drift: one
list of full indices, one map, no second notion of which line is kept.

## Existing entities this depends on

| Entity | File | Role |
|---|---|---|
| `SpanBuilder` | `lib/src/code_field/span_builder.dart` | One of the two files this spec changes. Owns the walk, the `_visibleLineIndex`, the `rootStyle`, the kept-line derivation and the splice. |
| `SpanBuilder.withFoldEllipsis` | `span_builder.dart:38`, `:52-57` | Internal switch, default `true`. `CodeController._createTextSpan` passes `visibleSearchResult.matches.isEmpty` (`code_controller.dart:1361`), so the marker is dropped while the search panel is slicing matches out of the tree. `SpanBuilder` is not in the barrel (`lib/zuraffa_code_editor.dart`), so this is not public API. |
| `SpanBuilder._foldedKeptLines` | `span_builder.dart:44`, derived at `:190-203` | The kept visible lines, resolved once per build. |
| `SpanBuilder._treeEndsWithNewline` | `span_builder.dart:50`, maintained at `:135-138` | Whether the last node with text ends in `'\n'`; the guard that tells the two splices apart. |
| `SpanBuilder.rootStyle` | `span_builder.dart:30`, `:55` | The base style the marker carries; the `style` argument `CodeController._createTextSpan` forwards at `code_controller.dart:1369-1373`. |
| `SpanBuilder._visibleLineIndex` | `span_builder.dart:40`, reset at `:60` | The visible line index the walk is on. Read *before* `_updateLineIndex(node)` it is the line the node starts on — which is why `_paleIfRequired` (`span_builder.dart:205-217`) is called at `:116`, before the increment at `:118`. |
| `SpanBuilder._updateLineIndex` | `span_builder.dart:134-145` | Advances the index by the node's own newline count, clamped to `code.lines.length - 1`, and records whether the value ended with a newline. After `splitLines` a node carries at most one newline, at its end. |
| `SpanBuilder._markFoldIfKeptLine` | `span_builder.dart:149-180` | The splice itself. |
| `Code.visibleHighlighted` | `code.dart:43`, built at `code.dart:150-152` | `hiddenRanges.cutHighlighted(highlighted)?.splitLines()` — the tree the walk visits. Every visible line is terminated by a node whose own value ends with `'\n'`, except the final line. |
| `Code.visibleText` | `code.dart:44`, `:153` | `hiddenRanges.cutString(text)` — the editing buffer. Must stay byte-for-byte identical when folding. |
| `Code.foldedBlocks` | `code.dart:36` | `Set<FoldableBlock>`, grown by `foldedBlock` (`code.dart:588-604`) and shrunk by `unfoldedAt` (`code.dart:606-617`); re-derived by `foldedAs` (`code.dart:744`) on every edit. |
| `FoldableBlock.firstLine` | `lib/src/folding/foldable_block.dart:9` | The full-buffer line index of the block's kept line. |
| `HiddenLineRanges.cutLineIndexIfVisible` | `hidden_line_ranges.dart:65-67` | Full → visible, `int?`. Null when the line is hidden. |
| `HiddenLineRanges.recoverLineIndex` | `hidden_line_ranges.dart:69-71` | Visible → full, `int`. Used by `_paleIfRequired` at `span_builder.dart:84`. |
| `HiddenLineRanges.visibleLineNumbers` | `hidden_line_ranges.dart:73` | The visible line indices in order — the domain the gutter and the line-number column iterate. |
| `MyResult.splitLines` | `lib/src/highlight/result.dart:44-46` | The call that puts one line per node-value in the tree. |
| `MyNode.splitLines` | `lib/src/highlight/node.dart:55-70` | Splits a node's value on `'\n'`, giving each piece a trailing `'\n'` except the last, and children only on the first piece. |
| `Code.foldableBlockToHiddenRange` | `code.dart:636-717` | Decides what the fold leaves on screen, and therefore where the marker lands. |
| `CodeController._createTextSpan` | `code_controller.dart:1366-1377` | Chooses the `SpanBuilder` path (`_language != null`) or the raw `TextSpan(text: text)` path. |
| `SearchResultHighlightedBuilder.build` | `lib/src/code_field/search_result_highlighted_builder.dart:92-110` | Flattens the tree when there are matches, returning it unchanged when there are none. Its window into the tree is measured in offsets against `code.text`, which is why the marker is suppressed rather than flattened. |

## Coordinate spaces

Two, and conflating them is the one way to get this feature wrong.

| Space | Values | Produced by |
|---|---|---|
| Full line index | `0 … code.lines.length - 1` | `FoldableBlock.firstLine`, `FoldableBlock.lastLine`, `code.lines` |
| Visible line index | `0 … code.hiddenLineRanges.visibleLineNumbers.length - 1` | `SpanBuilder._visibleLineIndex`, `recoverLineIndex`'s inverse |

`FoldableBlock.firstLine` lives in the **full** space: it is the same index the
gutter uses to hang a fold toggle (`gutter.dart:257`, via `_lineIndexToTableRowIndex`
at `gutter.dart:297-299`) and the same one `lineBackgroundBuilder` hands a host
(#86). The walk's `_visibleLineIndex` lives in the **visible** space. The marker
belongs at the visible line `cutLineIndexIfVisible(block.firstLine)` — the one
place the two spaces are bridged, using the map that already bridges them
everywhere else.

Note the clamp at `span_builder.dart:142-144` compares `_visibleLineIndex`
against `code.lines.length`, which is the *full* count. Pre-existing, harmless
(the visible count is never larger, so the clamp only ever engages at the end of
the document, where it is correct), and unchanged here — but worth knowing before
anyone reads `_updateLineIndex` and wonders which space it is counting.

## The splice, as a state transition

The implementation splices the marker **in front of the terminating node's
trailing newline run**, not as a child appended after the node's whole value.
Both put the glyph at the end of the line's text; only one is correct, and the
reason is worth recording, because the other is the obvious reading of the
`splitLines` contract.

`MyNode.splitLines` (`node.dart:55-70`) gives the *first* piece of a split node
**both** a value and children (`node.dart:62-67`):

```dart
copyWith(
  value: splitValue[i] + (i == splitValue.length - 1 ? '' : '\n'),
  children: i == 0 ? children?.splitLines() : null,
)
```

So a terminating node is not guaranteed to be a leaf. If it has children, they
render *after* the node's own value inside the `TextSpan`, and the node's own
value is a newline — meaning the children are already on the following line.
Appending the marker as the node's last child would therefore put it after the
*next* line's text, not at the end of the kept line. `_markFoldIfKeptLine`
(`span_builder.dart:149-180`) splits the node's own value at the start of its
trailing newline run and rebuilds the span as:

```dart
TextSpan(
  style: span.style,
  children: [
    TextSpan(text: text.substring(0, runStart), style: span.style),
    ...?span.children,                                          // the following line
    TextSpan(text: _foldEllipsis, style: rootStyle ?? span.style),
    TextSpan(text: text.substring(runStart), style: span.style), // the newline(s)
  ],
)
```

so the node's children stay behind the marker and the marker stays on the kept
line. Splitting on the *run* of trailing newlines rather than on the last
character is what handles a value ending in more than one `'\n'` — and an empty
kept line (`foo(` / `` / `)`) puts the marker on the empty line rather than
after it, which the source comment at `span_builder.dart:161-163` calls out.

| Step | State | Effect |
|---|---|---|
| `build()` | `_visibleLineIndex = 0`, `_treeEndsWithNewline = false` | `_foldedKeptLines` derived from `code.foldedBlocks` (`span_builder.dart:62`); the marker is known before the first node is visited. |
| A node starts on visible line L | `_visibleLineIndex == L` | If L is in `_foldedKeptLines`, this node is a candidate — it gets the marker only if it terminates L. |
| `_updateLineIndex` has just run | `_visibleLineIndex` is the line *after* the one a newline-terminating node ended | Hence the membership test in the splice is `_foldedKeptLines.contains(_visibleLineIndex - 1)` (`span_builder.dart:157`). |
| The node's own value ends with `'\n'` | it terminates L | The marker is spliced in front of that newline run. |
| The node's value has no newline | mid-line | No marker; the walk continues. |
| The last node with text ends with `'\n'` | every visible line is terminated | `_treeEndsWithNewline` is true and `build()` returns the plain tree (`span_builder.dart:70-72`). |
| The tree ends mid-line | the last visible line has no terminating newline | `_visibleLineIndex` is that last line, and if it is kept the marker is appended to the end of the whole walk (`span_builder.dart:74-87`). |
| A block is unfolded | its line leaves `_foldedKeptLines` | No marker; the tree is byte-for-byte the pre-fold tree. |

Because the marker is a sibling of the node's value-tail rather than a child of
the node's span, the "no newline to splice before" case needs no separate rule
about which node to attach to: the walk's last span is the only span there is.

## The search-match branch

`CodeController.buildTextSpan` builds the `SpanBuilder` tree **with the marker
switched off** whenever the search result has matches, and on when it does not
(`code_controller.dart:1358-1361`), threaded through `_createTextSpan`'s new
`withFoldEllipsis` parameter (`code_controller.dart:1374-1391`).

This is a real constraint, not a precaution.
`SearchResultHighlightedBuilder` tracks a window into the **real** text while it
flattens the tree: `_currentWindowStart` is advanced by each leaf's
`text.length` (`search_result_highlighted_builder.dart:130`), and match
boundaries come from `matchIndexes`, which are offsets into `code.text` — a
string that carries no marker (`:37-39`, `:126`). A marker leaf hit mid-walk
would advance the window by 2 characters the matches do not account for, and
every match after it would be sliced off the wrong text. The marker is therefore
absent while the search panel is filtering, and returns the moment the pattern is
cleared — the right trade, since the panel is transient and the fold is not.

The alternative — keeping the marker and teaching the search builder to skip it —
would mean giving `SearchResultHighlightedBuilder` a notion of "characters that
are painted but not indexed", a second class of text in a class that currently
has one. Suppressing the marker at the source is one line and needs no change to
the search builder at all.

## Edge cases and their expected outcome

| Case | Shape | Outcome |
|---|---|---|
| Nothing folded | `foldedBlocks` empty | `_keptVisibleLines` empty, tree unchanged |
| One folded block | kept line + glued closer | One marker after the closer's last character |
| Closer on its own row | `}void main(){` (`code.dart:670-708`) | Marker on the opener's row only; the closer's row gets none |
| Nested fold, outer already folded | `foldAt(2); foldAt(3)` on the #213 fixture | `cutLineIndexIfVisible(3)` is null, so the inner block contributes nothing; the outer block's marker is unaffected |
| Adjacent folds | two disjoint blocks, both folded | Two markers, one per kept line |
| Two blocks sharing a first line | joined by `joinIntersecting` (`foldable_block.dart:139-151`) | One marker — the `Set` collapses them |
| Kept line is the final visible line, no trailing newline | a comment block folded down to its first line | No node terminates the line with `'\n'`; `_treeEndsWithNewline` stays false and the marker is appended to the end of the walk (`span_builder.dart:74-87`) |
| Stale/invalid folded block | in `foldedBlocks`, no longer in `foldableBlocks` | Its first line is still kept visible by its own range, so it still gets a marker — the gutter still shows a chevron for it too (`gutter.dart:279-294`), and the two agree |
| Wholly hidden first line | only reachable via an enclosing fold | Null from `cutLineIndexIfVisible`, no marker, no crash |
| No language configured | `_createTextSpan` returns `TextSpan(text: text)` (`code_controller.dart:1376`) | No marker — and no folds either (`code.dart:80-93`) |
| Active IME composition | `super.buildTextSpan` (`code_controller.dart:1338-1347`) | No marker; returns with the composition |
| Search result non-empty | `withFoldEllipsis: visibleSearchResult.matches.isEmpty` (`code_controller.dart:1361`) | No marker while matches are being sliced out of the tree; it returns when the pattern is cleared |

## The nested-fold branch, spelled out

This is the one branch that looks like defensive code and is not, so it gets its
own paragraph. `code_controller_fold_blocks_test.dart:26-31` records the
behaviour: folding a block nested inside an already-folded block "leaves the
visible value equal", because the inner range is subsumed by the outer one. The
inner block is nevertheless still in `code.foldedBlocks` — `foldedBlock` adds it
unconditionally (`code.dart:600-603`). Its `firstLine` therefore lies inside the
outer block's hidden range, and `cutLineIndexIfVisible` returns null for it
(`hidden_line_ranges.dart:65`).

The correct outcome is no marker for that block: its kept line is not rendered,
so there is no row to put one on, and the outer block's marker already marks the
row the reader sees. `test/src/folding/folded_block_keeps_next_block_start_test.dart:121-134`
pins this exact double fold and the exact visible text it produces, so the test
for FR-9 has a ready-made fixture rather than a synthetic one.

## What the marker is not

- It is not a character in `visibleText`. Nothing in `cutString`, `cutSelection`,
  `recoverSelection` or `getEditResult` learns about it.
- It is not a `WidgetSpan`. A widget would need a build context inside a
  `TextSpan` tree that is built outside the element tree, would break
  `visitChildren`-based flatteners, and would change the paragraph's inline
  semantics for the price of one glyph.
- It is not stored, cached or exposed. `lastTextSpan`
  (`code_controller.dart:1356`) is cached by the controller already and carries
  the marker with it; the spec adds no cache of its own.
