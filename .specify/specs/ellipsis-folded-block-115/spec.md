# Spec: ellipsis-folded-block

Fork issue: #115 · Upstream: akvelon/flutter-code-editor#86
Label: `spec` · Severity: `low` · Backlog rank: 18

## What was asked

"Render an ellipsis or chevron on the folded line so hidden content is visible."

## What exists today

Foldedness is already visible in the gutter. `FoldToggle`
(`lib/src/gutter/fold_toggle.dart`) renders a `RotatedBox` of
`Icons.chevron_right` in the gutter's folding column for every
`code.foldableBlocks` entry — one quarter-turn when unfolded, none when folded —
and `GutterWidget._fillFoldToggles` (`lib/src/gutter/gutter.dart:253-275`) places
it on the row of `block.firstLine`. A second loop at `gutter.dart:279-294`
re-hangs the toggle for blocks that were folded and have since become invalid,
so a stale fold still reads as folded. Clicking the chevron unfolds
(`gutter.dart:268-270`). So a reader can already tell *that* something is
folded, and can act on it.

What is missing is any indication of *where the hidden content began*, inside
the text. A folded line reads as merely short. `Code.foldableBlockToHiddenRange`
(`lib/src/code/code.dart:636-717`) deliberately keeps the block's first line on
screen and ends the hidden range at the closer, so the row that survives is a
real line of real code that stops mid-thought with nothing to say so. On the
fixture the repo already pins in
`test/src/folding/folded_closing_line_test.dart:36-50`, folding `  parsers: [`
renders

```java
  parsers: [  ],
```

— and the reader has to know the fold machinery to notice that four lines are
gone. The gutter chevron sits on the same row, but it says "folded", not "more,
here", and it is 16px of gutter away from the text.

## What this spec adds

One marker, painted at the end of the kept line's own text. Nothing else: no
character enters the buffer, no offset moves, no public API changes.

The marker is the single character U+2026 HORIZONTAL ELLIPSIS, preceded by one
ASCII space: `' …'`. The space is what keeps it legible after a closing bracket
(`[  ], …` rather than `[  ],…`) and it costs one character, which matters only
where the line is at the right edge of the viewport — and that is exactly where
the reader is looking for the marker.

## Decisions

- **The marker is painted, not typed.** This is the load-bearing constraint and
  it is settled in `research.md` R3; restated here because every other decision
  hangs off it. `Code.visibleText` (`lib/src/code/code.dart:44`, computed at
  `code.dart:153`) is not a rendered projection of the buffer — it *is* the
  editing buffer. It becomes the `TextEditingController`'s value
  (`code_controller.dart:906-907` and `code_controller.dart:1285`), and
  `cutSelection`/`recoverSelection` (`hidden_line_ranges.dart:324-352`) map the
  caret and every selection through the same offsets, `Code.getEditResult`
  replays an edit of the visible text against the full text through a
  `TextEditingValue(text: visibleText, …)` (`code.dart:434`), and the gutter's
  line numbering is derived from the same breakpoints. An ellipsis inside that
  string would shift every offset after it by one character, become selectable,
  deletable and typeable-over, and corrupt the numbering for every folded
  document. So the marker is a paint-time addition to the span tree, and
  `controller.text` must be byte-for-byte identical folded and unfolded — which
  is an asserted requirement (FR-3), not an aspiration.

- **It is appended to the span tree in `SpanBuilder`, not drawn as an overlay
  and not given a gutter column.** `research.md` R4 records both alternatives
  with their costs. The overlay (`LineBackgroundLayer`-style) would have to
  measure the line's text to find its end, or reach into
  `RenderEditable.getLocalRectForCaret` across an independently-scrolling
  `SingleChildScrollView` (`code_field.dart:657-665`) — strictly more machinery
  for the same visual, and a way to drift from the text it annotates. A fourth
  gutter column changes the three-column `Table`'s width sum
  (`gutter.dart:106-122`), so every host's text x-offset moves whether or not
  the document has a fold, and the same objection already killed narrowing an
  existing column for #107 (`gutter.dart:160-174`). Splicing a `TextSpan` into
  the node that already ends the kept line needs no measurement at all: it
  paints at whatever offset and baseline the line's own text paints at, through
  the same `TextPainter`, at any wrapping, in any direction. It is one splice in
  one place that already tracks the line index.

- **It sits at the end of the kept line's text.** `foldableBlockToHiddenRange`
  (`code.dart:636-717`) ends the range at the start of a closing line so the
  closer stays on screen (`code.dart:643-649`), which glues the closer onto the
  opener's row — the shape the source's own comment calls out as
  `parsers: [` → `parsers: [  ],` (`code.dart:666-668`). The marker therefore
  belongs after whatever the fold left at the end of that row: after the glued
  closer, or after the opener when the closer took a row of its own, or after
  the last comment line of a comment block. It is one rule — "the last visible
  character of the kept line" — applied uniformly, and it is where VSCode puts
  its ellipsis.

- **The marker does not inherit the token's colour.** An ellipsis that lands at
  the end of a string literal must not look like part of the string; the same
  applies to a comment or a keyword run. The style is the field's base style —
  `SpanBuilder.rootStyle` (`span_builder.dart:12`), the `style` Flutter passes
  into `buildTextSpan` and which `CodeController._createTextSpan` forwards
  (`code_controller.dart:1369-1373`) — falling back to the terminating node's
  own style when the root style is null, which is the only other style in scope
  that is guaranteed non-null on a rendered line.

- **It is not configurable in this iteration, and that is deliberate.** No
  constructor parameter, no field on `CodeController`, no new public type, no
  new export. The issue asks for a marker; it does not ask for a choice of
  glyph, size, colour, prefix or position. Every one of those is a permanent
  public-surface commitment made on the evidence of one issue, and a field that
  cannot be turned off is worse than one that does not exist. This is recorded
  here so a reviewer can hold the line, and it is restated in
  `plan.md` §Complexity budget.

- **Only the language path gets the marker.** `_createTextSpan`
  (`code_controller.dart:1366-1377`) returns `SpanBuilder(...).build()` only
  when `_language != null`; with no language it returns `TextSpan(text: text,
  style: style)` straight from the controller's value. A field with no language
  therefore has no fold machinery either — `Code`'s constructor only parses
  `foldableBlocks` when both `highlighted` and `language` are present
  (`code.dart:80-93`) — so there is nothing to mark. This is stated as an
  assumption rather than a gap, and the no-language render path is asserted
  unchanged rather than left to inference.

- **The marker disappears during an active IME composition, and that is
  correct.** `CodeController.buildTextSpan` (`code_controller.dart:1332-1364`)
  delegates to `super.buildTextSpan` while `hasActiveComposition`
  (`code_controller.dart:1338-1347`) precisely so the composing range survives;
  that path builds its span from the controller's value and never reaches
  `SpanBuilder`. The marker is absent while composing and returns the moment the
  composition ends. Documented, not fixed.

## Out of scope

- Configurability of any kind: glyph, colour, size, prefix, suffix, or which
  lines get one. Explicit non-goal — see Decisions.
- Changing the gutter chevron, or moving the indicator into the gutter.
- A fourth gutter column, or any change to the gutter's column widths for any
  reason (`research.md` R4 Option C).
- A paint-only overlay layer (`research.md` R4 Option B).
- Any change to `foldableBlockToHiddenRange`, `cutString`, `cutSelection`,
  `recoverSelection`, `getEditResult` or the line-numbering breakpoints. The
  folding machinery is pinned by its own tests and is not the subject of this
  issue.
- Any new behaviour for the no-language path, or during IME composition — both
  are documented as-is.
- Selection, hit-testing or caret positioning on the marker. Research records
  the one cosmetic consequence (a caret parked on the folded line renders to the
  right of the ellipsis); changing hit-testing to fix it would mean changing
  offsets derived from `value.text`, which is the one thing this spec must not
  do.

## Assumptions

- The marker's audience is a human reading folded code. Automated consumers that
  walk the span tree — the search-match flattener, the test suite — are
  accounted for rather than served.
- Flutter's `EditableText` never asserts that the span's plain text equals
  `value.text`. Verified rather than assumed: `EditableText.buildTextSpan`
  (`editable_text.dart:6027`) delegates to `widget.controller.buildTextSpan`
  (`editable_text.dart:6093-6096`), `EditableText.getGlyphHeights`
  (`editable_text.dart:3167-3179`) compares `span.toPlainText()` against
  `textEditingValue.text` and falls back to `preferredLineHeight` on mismatch,
  and the Scribble path (`editable_text.dart:5060`) derives its graphemes from
  the span's own plain text and resolves them through
  `RenderEditable.getBoxesForSelection` → `TextPainter.getBoxesForSelection`
  (`text_painter.dart:1666-1688`), which clamps to the laid-out text. No
  assertion exists that the two strings are equal, which is what makes a
  paint-only marker possible at all.
- `SearchResultHighlightedBuilder.build()`
  (`search_result_highlighted_builder.dart:92-110`) flattens the tree by
  visiting children in order when there are matches; with none it returns the
  tree unchanged (`:93-95`). Match boundaries come from `cutSearchResult`
  (`hidden_ranges.dart:356-367`) and are offsets into `code.text` — a string
  with no marker in it. Checked: with the marker in the tree the highlight
  lands two characters early, on `  two` instead of `two()`, which is a test
  rather than a prediction. Hence FR-12.
- Every visible line is terminated by a node whose own value ends with `'\n'`,
  except the final visible line, which has no trailing newline. This follows
  from `Result.splitLines()` (`result.dart:44-46`) → `MyNode.splitLines`
  (`node.dart:55-70`), where each split piece carries `splitValue[i] + '\n'`
  and children only on the first piece, and it is the rule the splice depends
  on.
- A node in the highlight tree does **not** carry either a `value` or `children`
  exclusively. `MyNode.splitLines` (`node.dart:55-70`) gives the first piece of a
  split node **both**: `copyWith(value: splitValue[i] + '\n', children: i == 0 ?
  children?.splitLines() : null)` (`node.dart:62-67`). A terminating node can
  therefore have children, and those children render after the node's own value —
  which is a newline, so they are already on the following line. This is why the
  marker is spliced *in front of* the node's trailing newline run
  (`span_builder.dart:149-180`) rather than appended as the node's last child:
  the latter puts it after the next line's text. Splitting on the run of
  trailing newlines also covers a value ending in more than one `'\n'`, and an
  empty kept line (`foo(` / `` / `)`) marks the empty line rather than the one
  after it.
- The search-match path **suppresses** the marker rather than carrying it.
  `SearchResultHighlightedBuilder` flattens the tree while advancing a window
  into the *real* text by each leaf's length
  (`search_result_highlighted_builder.dart:130`) and slicing against
  `matchIndexes`, which are offsets into `code.text` — a string with no marker
  in it (`:37-39`, `:126`). A marker leaf mid-walk would shift every match that
  follows it off its own text, so `CodeController.buildTextSpan` builds the tree
  with `withFoldEllipsis: visibleSearchResult.matches.isEmpty`
  (`code_controller.dart:1358-1361`). Verified by reading `_processText`
  (`:120-151`) rather than assumed, and pinned by a test.

## Functional requirements

- **FR-1** When a block is folded, the visible line that keeps `block.firstLine`
  ends with `' …'` immediately after its last visible character.
- **FR-2** With nothing folded, the span tree is byte-for-byte what it is today
  — the existing `span_builder_test.dart` examples pass unmodified.
- **FR-3** `controller.text` is byte-for-byte identical before a fold, after a
  fold, and after unfolding: the marker never enters
  `TextEditingController.value.text`, which is `code.visibleText`
  (`code.dart:153`, assigned at `code_controller.dart:906-907` / `:1285`).
- **FR-4** Unfolding removes the marker; no trace of it survives in the tree.
- **FR-5** The marker survives a re-parse: typing a keystroke on the kept line
  re-derives `Code` through `foldedAs` (`code.dart:744`) and the marker is still
  there, on the same logical line.
- **FR-6** The marker lands after the closer when the closer shares the kept row
  (`parsers: [` → `parsers: [  ],`, as `code.dart:666-668` describes).
- **FR-7** The marker does not appear on the closer's own row when the closer
  took a row of its own (`}void main(){`, `code.dart:670-708`, pinned by
  `test/src/folding/folded_block_keeps_next_block_start_test.dart:46-54`).
- **FR-8** A kept line that is also the last visible line, with no trailing
  newline, still gets the marker (`node.dart:55-70` leaves the final piece
  without a `'\n'`).
- **FR-9** Exactly one marker per kept line: a fold whose inner block is itself
  hidden by an outer fold contributes nothing, because
  `cutLineIndexIfVisible` returns null for a hidden line
  (`hidden_line_ranges.dart:65`, pinned by
  `test/src/folding/folded_block_keeps_next_block_start_test.dart:121-134`).
- **FR-10** Two folded blocks that are both visible — nested around a visible
  line, or adjacent to each other — each get their own marker.
- **FR-11** The marker carries the field's base style (`rootStyle`), never the
  style of the token it follows.
- **FR-12** The marker is absent while a search pattern is active, because the
  search builder slices the tree against offsets into `code.text`, which carries
  no marker (`search_result_highlighted_builder.dart:120-151`,
  `code_controller.dart:1358-1361`); it returns when the pattern is cleared.
- **FR-13** No new public API: no field on `CodeController`, no new exported
  type, no change to `SpanBuilder`'s required parameters. The one new parameter,
  `SpanBuilder.withFoldEllipsis` (`span_builder.dart:38`, default `true`), is on
  a class the barrel does not export (`lib/zuraffa_code_editor.dart`), exists
  only to suppress the marker, and is unreachable from a host.

## Success criteria

- A `CodeField` showing the `parsers: [` fixture, folded at line 2, renders
  `  parsers: [  ], …` — the closer on screen, the marker after it — while
  `controller.text` still reads `  parsers: [  ],` exactly as
  `test/src/folding/folded_closing_line_test.dart:36-50` pins it.
- The same field unfolded renders no ellipsis anywhere, and the existing
  `span_builder_test.dart` expectations are unchanged.
- A caret, a selection and a search match all behave as they do today: no
  exception, no offset shift, no renumbered gutter.
- The full suite, `dart analyze --fatal-infos`,
  `dart format --output=none --set-exit-if-changed .` and
  `python3 tool/coverage_gate.py --min 100` are all green, with no exemption
  added for this feature.

## Acceptance criteria

- [ ] `SpanBuilder.build()` appends `' …'` to the span that ends the kept line of
      every folded block whose first line is visible.
- [ ] Nothing else in the tree changes: same nodes, same order, same styles,
      same text.
- [ ] `controller.text` is byte-for-byte unchanged by folding and unfolding.
- [ ] No ellipsis with no folds; no ellipsis after an unfold.
- [ ] The marker survives a re-parse after a keystroke on the kept line.
- [ ] The marker is after the glued closer in the shared-row shape, and absent
      from the closer's own row in the own-row shape.
- [ ] A kept line that is the last visible line with no trailing newline still
      gets the marker.
- [ ] One marker per kept line, including the nested-fold-swallowed case.
- [ ] The marker carries `rootStyle`, not the token style.
- [ ] The marker is suppressed while a search pattern is active and returns when
      it is cleared.
- [ ] All three files in `test/src/code_field/span_builder_test.dart`'s existing
      examples pass unmodified, as do the folding regression files.
- [ ] Coverage stays at the 100% gate; every new branch has a named test.

## Gates

`flutter test --concurrency=2` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
