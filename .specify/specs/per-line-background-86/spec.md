# Spec: per-line-background

Fork issue: #86 · Upstream: akvelon/flutter-code-editor#239
Label: `spec` · Severity: `medium` · Backlog rank: 6

## What was asked

"Allow the background colour of individual code lines to be set, so a host can
highlight the current line, search hits, error lines, and so on."

The upstream body is a single sentence: the reporter wants to change the colour
of a particular code line and reports it is not possible. Today the only
background a host can reach is `CodeField.background`, which is one colour for
the whole editor, and `CodeThemeData.styles`, which is per token class, not per
line. Every host that wants a current-line tint, a search-hit tint or an
error-line tint therefore builds its own overlay on top of the field and keeps
it in sync with scrolling, folding and wrapping by hand.

This is the mechanism half of a pair. The use cases are tracked separately:
#113 (highlight the cursor line) and the search-hit case both land on top of
whatever this spec adds, and neither can be built without it.

## What exists today

`CodeField.build()` (`lib/src/code_field/code_field.dart:539`) renders a
`FocusableActionDetector` > `Container` (carrying `decoration` / the
editor-wide `background` colour) > `Row` of [gutter, `editingField`]. The text
itself is a plain `TextField`; nothing on that path knows about individual
lines.

`CodeController.buildTextSpan()` (`lib/src/code_field/code_controller.dart:1254`)
is the render entry point. It calls `_createTextSpan()`
(`code_controller.dart:1287`), which has two shapes:

- **A language is set** — `SpanBuilder` (`lib/src/code_field/span_builder.dart`)
  walks `code.visibleHighlighted` and, in `_buildNode()`, picks a style per
  highlight node from the theme. `_updateLineIndex()`
  (`span_builder.dart:71`) accumulates the node's newline count into
  `_visibleLineIndex`, so **the builder already computes which visible line each
  span belongs to**. That counter is the natural anchor for a per-line hook, but
  two properties of it must be respected (see Decisions).
- **No language is set** — the whole buffer is returned as a single
  `TextSpan(text: text, style: style)`. There is no line structure at all.

`SearchResultHighlightedBuilder`
(`lib/src/code_field/search_result_highlighted_builder.dart`) then post-processes
the finished span tree and, per match, re-wraps the matched run with
`backgroundColor` — it is the only existing per-something colour in the editor,
and its tests
(`test/src/code_field/search_result_highlighted_builder_test.dart`) assert span
structure, not painted pixels.

Gutter-side, `GutterWidget` (`lib/src/gutter/gutter.dart`) already builds one
`TableRow` per visible line and is driven by the same `ScrollController` as the
field, and `CodeField` already measures per-row heights for wrapped lines
(`_measureWrappedRows`, used for gutter alignment). So the "one row per visible
line" layout machinery the background needs already exists on the gutter side.

### A measured constraint: `TextStyle.backgroundColor` is not a line background

Setting `backgroundColor` on the spans of a line does **not** tint the line. It
tints the glyph run's extent only. Measured directly (render `'zz'` at 20px into
a 300px-wide `TextPainter`, with and without `backgroundColor`, and compare the
painted extents): both produce an identical band exactly 40px wide — the advance
of the two glyphs — and nothing beyond it. The highlight therefore stops at the
last character of the line and the rest of the row stays the editor colour.

Any implementation that reaches for `TextStyle.backgroundColor` alone gives a
highlight that is wide only as far as the line is long. A short line gets a short
highlight; a line padded with trailing spaces gets a long one. That is not what
"highlight the line" means, so the painted extent is a hard requirement here,
not a nice-to-have.

## What this spec adds

One nullable hook on `CodeController`:

1. **`CodeController.lineBackgroundBuilder`** —
   `Color? Function(int lineIndex)?`, default `null`. When set, the render path
   consults it per rendered line and tints that line's row with the returned
   colour. Returning `null` leaves the line untinted. When the hook is `null`
   the render path is byte-for-byte what it is today.

No other public surface changes. `CodeController` is already exported, so there
is no new export.

## Decisions

- **The default does not change.** A controller with no builder renders exactly
  as before, on both the language and the no-language path. The feature is
  purely additive and opt-in, matching how `GutterStyle.errorPopupBuilder`
  landed (#81 part two).

- **The tint covers the row, not the glyph run.** Because of the measurement
  above, the implementation may not rely on `TextStyle.backgroundColor` alone to
  carry the requirement. Acceptable routes, in rough order of preference, all
  decided at plan time:
  - paint the rects behind the text, reusing the per-row heights `CodeField`
    already measures for gutter alignment and the scroll controller the gutter
    already shares;
  - per-line span wrappers, if and only if the tint is also demonstrated to
    reach the row edge.
  The spec's requirement is the outcome: the tint spans the full width of the
  line's row, including the part past the last character.

- **The builder receives the line's index in the full, unfolded buffer.** The
  coordinate space is the one the package already uses for per-line data:
  `Issue.line`, `FoldableBlock.firstLine`, and
  `HiddenLineRanges.recoverLineIndex(visibleLineIndex)`. Note that the gutter
  *displays* that index plus one (`gutter.dart:205`), so a host translating from
  the number it sees in the gutter subtracts one. The spec deliberately reuses
  the package's existing coordinate space rather than inventing a second one.

- **The builder is consulted per visible line, and only for lines that are
  actually rendered.** A line inside a folded block or a hidden section is not
  on screen, so it gets no tint and the builder is not asked about it. This
  follows from the anchor being a *visible* index mapped back to the full index.

- **`SpanBuilder`'s `_visibleLineIndex` is clamped and node-scoped, so it is not
  by itself a safe source of the line index.** `_updateLineIndex`
  (`span_builder.dart:71`) clamps to `code.lines.length - 1`, and a highlight
  node can carry several newlines at once (a multi-line string or block
  comment), which would attribute every line it covers to its last line. A
  background applied to such a node covers all of its lines. The implementation
  must therefore attribute background per **line**, not per node, and a test
  must pin the multi-line-node case and the trailing-newline case.

- **A background must not become a character.** Appending padding to make the
  tint wider is not an option: the span tree is what `EditableText` edits and
  hit-tests, so invented characters would corrupt caret position, selection and
  every existing text assertion.

- **Layering with the search highlight is preserved.** `SearchResultHighlightedBuilder`
  runs after this hook and re-wraps matched runs with its own `backgroundColor`.
  A line tint must sit behind it: on a matched run the search colour still wins,
  and outside matches the line tint is unchanged.

- **The hook is a mutable field, not a constructor-only value.** A current-line
  highlight changes on every caret move, so the host must be able to reassign
  the hook and have the next build pick it up without reconstructing the
  controller. `CodeController` is a `TextEditingController` and already
  notifies listeners for other rebuild triggers, so no new plumbing is required.

## Out of scope

- The current-line highlight itself (#113), the search-hit tint, and the
  error-line tint. Those are consumers of this hook and are tracked separately.
- Per-line text colour, borders, or anything other than a background colour.
- Ranges that do not start at column 0 — a line, not a span, is the unit here.
- Per-line styling of the gutter (that is `GutterStyle`'s problem, and the
  gutter's own cells already take a `textStyle`).
- Changing how `code.lines`, `hiddenLineRanges`, or `SpanBuilder` model lines.
- Caching the span tree (#114) — orthogonal, and it must not be a prerequisite
  for this.

## Risks

- **The row-extent requirement is the whole difficulty of this feature.** A
  tint that stops at the last glyph (the measurement above) is a plausible
  halfway implementation that looks right on a line that happens to be as wide
  as the viewport. The acceptance criteria below are written so that a test
  fails in that case; the plan must name the mechanism it chose.
- **The no-language path has no line structure.** It returns one span for the
  whole buffer, so there is nothing to attribute a background to. A host with no
  `language` set must either be given line structure on that path (only when a
  builder is set, so the default path is untouched) or the limitation must be
  documented and pinned by a test. Silently ignoring the builder on that path is
  not acceptable.
- **`code.lines.length` and the visible index disagree under folds.** The
  clamping in `_updateLineIndex` is a live symptom. Any implementation must be
  tested with a fold open over the target line.
- **Performance.** The hook runs once per rendered line on every rebuild. A
  host that recomputes on caret move must not push a synchronous layout cost
  into the keystroke path; the existing `no_language_keystroke_test.dart` pin is
  the guard.
- **Painted-width claims are not directly assertable in this repo's test
  style.** Existing background tests (`search_result_highlighted_builder_test.dart`)
  assert span structure. The row-extent requirement therefore needs an explicit
  test strategy chosen at plan time — most likely a widget test that reads the
  geometry actually produced for a short line rather than only the span tree.

## Note for whoever edits the render path next

`tool/coverage_gate.py` pins `EXEMPT_LINES` by **line number**. Inserting lines
above an exempted line shifts it and the gate goes red with a "matches nothing"
or a bare miss. This change adds code around `span_builder.dart`, and the
"stale line exemption" line the tool prints is the signal to renumber.

## Acceptance criteria

- [ ] `CodeController` accepts `lineBackgroundBuilder`, nullable, typed
      `Color? Function(int)?`, defaulting to `null`.
- [ ] A controller with the builder `null` produces the same `TextSpan` tree as
      before, on both the language and the no-language path.
- [ ] A set builder tints every visible line it returns a colour for, and leaves
      every line it returns `null` for untinted.
- [ ] The tint spans the full width of the line's row, including the stretch
      past the last character; a short line is fully tinted, not tinted only as
      far as its text reaches.
- [ ] The index handed to the builder is the line's index in the full, unfolded
      buffer — the same coordinate space as `Issue.line` and
      `FoldableBlock.firstLine` — and is correct with folds open, with hidden
      sections, and for a trailing newline.
- [ ] A line inside a folded block or a hidden section is not tinted, and no
      error is raised for it.
- [ ] A highlight node spanning several lines (block comment, multi-line
      string) does not leak its background onto the lines it merely passes
      through: a line is tinted by its own index only.
- [ ] Search-match highlighting still wins on matched runs; the line tint is
      visible everywhere else on a tinted line.
- [ ] Reassigning the hook on an existing controller and notifying re-renders
      with the new colours, without reconstructing the controller.
- [ ] No text character is added, removed, or reordered to carry the tint.
- [ ] The public API is exported as before (no new file needed).
- [ ] Coverage stays at the 100% gate; new branches are covered or proved dead.

## Gates

`flutter test --concurrency=2` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
