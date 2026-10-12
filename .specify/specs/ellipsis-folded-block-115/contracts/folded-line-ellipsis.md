# Contract: the folded-line ellipsis

The span-tree contract `SpanBuilder.build()` must satisfy. Everything not listed
here is unchanged, and no public API is added — the one new parameter,
`SpanBuilder.withFoldEllipsis` (`span_builder.dart:38`), is on a class that is
not in the barrel (`lib/zuraffa_code_editor.dart`) and is reached only from
`CodeController._createTextSpan`.

## What the tree carries

For each block in `code.foldedBlocks` (`code.dart:36`) whose `firstLine`
survives as a visible line, the tree returned by `SpanBuilder.build()`
(`span_builder.dart:59-88`) carries **one extra leaf**:

```dart
TextSpan(text: ' …', style: rootStyle)
```

placed **immediately before the newline run that ends the terminating node's own
value** (`span_builder.dart:149-180`). The terminating node's own value is split
around it — `span.children` stay behind the marker, the newline run stays after
it — and nothing else moves: no node is removed, reordered, re-styled or
re-texted, and no existing child is dropped.

`' …'` is one ASCII space followed by U+2026 HORIZONTAL ELLIPSIS. The leading
space separates the marker from the last visible character without a widget, a
separator span or a measurement.

## Position rule

The marker lands immediately after the **last visible character of the kept
line**, whatever that character is:

| What the fold left at the end of the kept row | Marker lands after |
|---|---|
| The opener alone | the opener (`parsers: [` …) |
| The closer glued onto the opener's row (`code.dart:666-668`) | the closer (`parsers: [  ], …`) |
| The closer on its own row (`code.dart:670-708`) | the opener — and *not* on the closer's row |
| The last of a run of `//` comment lines | that comment's last character |
| The block's only line, in a degenerate two-line fold | that line's last character |
| An empty kept line (`foo(` / `` / `)`) | on the empty line, not after it |

"Last visible character" is a statement about the rendered text, not about a node
boundary: the marker is spliced **in front of the terminating node's trailing
newline run** (`span_builder.dart:149-180`), so it paints at the offset and
baseline the line's own text paints at — under wrapping, in any text direction,
at any font size.

The splice splits the node's own value rather than appending to the node's
children, because a terminating node is not guaranteed to be a leaf:
`MyNode.splitLines` gives the first piece of a split node **both** a value and
children (`node.dart:62-67`). Those children render after the node's own value —
which is a newline — so they are already on the following line, and a marker
appended as the node's last child would land after the *next* line's text. The
split keeps the node's children behind the marker and the marker on the kept
line. Splitting on the *run* of trailing newlines, rather than on the last
character, is what handles a value ending in more than one `'\n'`.

## Guarantees that follow

- **`controller.text` is untouched.** The marker is added to the returned
  `TextSpan`, never to `code.visibleText` (`code.dart:153`) or to
  `TextEditingController.value.text` (assigned at `code_controller.dart:906-907`
  and `:1285`). No offset moves. `cutSelection`, `recoverSelection`,
  `getEditResult` (`code.dart:434`) and the line-numbering breakpoints all see
  the same string they saw before the feature.
- **`build().toPlainText()` is `value.text` with `' …'` inserted once per
  visible folded kept line.** It is longer than `value.text` by exactly
  `2 × (number of visible folded blocks)` characters. That is the entire delta,
  and it is the only observable difference between the two strings.
- **Nothing folded ⇒ nothing added.** With `code.foldedBlocks` empty the tree is
  byte-for-byte what `build()` returns today. The three examples in
  `test/src/code_field/span_builder_test.dart` are the proof, and they must pass
  unmodified.
- **One marker per kept line, never more.** A folded block whose first line is
  hidden — a block nested inside an already-folded one — contributes nothing,
  because `cutLineIndexIfVisible` returns null for it
  (`hidden_line_ranges.dart:65`) and the derivation discards nulls
  (`span_builder.dart:190-203`). Two folded blocks sharing a first line (which
  `joinIntersecting` at `foldable_block.dart:139-151` prevents for *foldable*
  blocks, but not for stale entries in `foldedBlocks`) collapse to one marker,
  because the derivation is a `Set`.
- **The marker carries the base style.** `style` is `SpanBuilder.rootStyle`
  (`span_builder.dart:30`), the style Flutter hands `buildTextSpan`, falling back
  to the terminating node's own resolved style when the root style is null
  (`span_builder.dart:176`). It never inherits the style of the token it
  follows, so an ellipsis after a string literal is not string-coloured, one
  after a `//` comment is not comment-coloured, and one on a read-only line —
  where `_paleIfRequired` palls the text around it — is not palled either: the
  marker is decoration, not content.
- **The marker is not selectable as an extra character.** Caret and selection
  offsets are derived from `value.text`, which does not contain it.
- **The marker is absent when the marker cannot be built.** No language set
  (`code_controller.dart:1376` returns `TextSpan(text: text)` directly), an
  active IME composition (`code_controller.dart:1338-1347` delegates to
  `super.buildTextSpan`), and a non-empty search result
  (`code_controller.dart:1358-1361`) all bypass or switch off the splice.

## Search-match path

`CodeController.buildTextSpan` builds the `SpanBuilder` tree with
`withFoldEllipsis: visibleSearchResult.matches.isEmpty`
(`code_controller.dart:1358-1361`), so **the marker is suppressed while the
search panel is slicing matches out of the tree**, and present the moment the
pattern is cleared.

This is a constraint of the search builder's own window arithmetic, not a
preference. `SearchResultHighlightedBuilder` walks the flattened tree keeping
`_currentWindowStart` — the position in the **real** text — advanced by each
leaf's `text.length` (`search_result_highlighted_builder.dart:130`), while match
boundaries come from `matchIndexes`, offsets into `code.text`
(`:37-39`, `:126`). A marker leaf hit mid-walk would advance the window by 2
characters that no match accounts for, and every match after it would be sliced
off the wrong text. With no matches `build()` returns the tree unchanged
(`:93-95`), so there is nothing to desynchronise and the marker stays.

The alternative — keeping the marker and teaching the search builder to skip it —
would give `SearchResultHighlightedBuilder` a notion of "characters that are
painted but not indexed", a second class of text in a class that has one.
Suppressing at the source is one line and touches nothing in the search builder.

Consequences a host can rely on: with a search pattern typed, folded lines show
no ellipsis; clear the pattern and they show it again. That is a real, visible
trade, and it is the right one — the panel is transient, the fold is not.


## Tree-shape guarantee

There is none to break: no widget enters or leaves the tree, no `Stack`, no
layer, no gate widens. `CodeField`'s widget tree is identical before and after
this change, folded or not. The only observable difference anywhere in the
package is in the `TextSpan` tree that `EditableText` receives
(`editable_text.dart:6093-6096`).

## What it does not do

- It does not make the marker configurable — no glyph, colour, size, prefix,
  suffix or position parameter, and no field on `CodeController`. This is an
  explicit non-goal of this iteration.
- It does not add public API. `SpanBuilder.withFoldEllipsis` is a new *parameter*
  on a class that is not exported, and it exists to switch the marker off, not
  to configure it; it has no public setter and no host-reachable default.
- It does not change the gutter: no chevron change, no fourth column, no width
  change for anyone.
- It does not change the folding machinery: `foldableBlockToHiddenRange`,
  `cutString`, `cutSelection`, `recoverSelection`, `getEditResult` and the
  line-numbering breakpoints are untouched.
- It does not change `SearchResultHighlightedBuilder`. The one place the marker's
  presence would have broken something was solved by not emitting it there.
- It does not change hit-testing, caret placement or selection behaviour. The
  one consequence — a caret parked on the folded line renders to the right of
  the ellipsis, because `RenderEditable` lays the span out and the caret is
  resolved from `value.text` — is cosmetic, is recorded as a known cost in
  `research.md` R4, and is deliberately not "fixed" by moving offsets derived
  from `value.text`.
- It does not export anything. `SpanBuilder` keeps its existing visibility; the
  marker constant is private to `span_builder.dart`.

## Gates

`flutter test --concurrency=2` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
