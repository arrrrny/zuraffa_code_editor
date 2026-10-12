# Phase 0 Research: per-line-background

All `NEEDS CLARIFICATION` items from the plan's Technical Context, resolved.

## R1 — How does a tint reach the full width of a line's row?

**Decision**: paint a background layer of tinted rows behind the `TextField`,
sized from the per-row heights the editor already measures. Do **not** carry the
requirement on `TextStyle.backgroundColor`.

**Rationale — measured, not assumed.** A `TextPainter` rendering `'zz'` at
fontSize 20 into a 300px-wide box produced an identical painted band with and
without `backgroundColor`: both exactly 40px wide, the advance of the two glyphs,
with nothing beyond. So a style-level background is a *glyph-run* background. It
stops at the last character of the line, which means:

- a short line gets a short tint,
- a line that happens to reach the right edge gets a full tint,
- the result depends on the content, not on the host's intent.

Both alternatives that keep the tint in styles were rejected outright:

- **Appending padding characters to widen the run** — the span tree is what
  `EditableText` edits, hit-tests and selects. Invented characters corrupt caret
  position and every existing text assertion.
- **Relying on `TextAlign.justify` or font metrics** — no effect on background
  extent.

The row-layer route reuses machinery that already exists for the gutter:
`_wrappedRowHeights(textStyle)` (`code_field.dart:722`, cached in
`_cachedRowHeights`) gives one height per visible line, and
`LinkedScrollControllerGroup` (`code_field.dart:355-357`) already links the
gutter's scroll to the editor's. A third member of the same group keeps a
background layer aligned for free. This is precisely the invariant
`test/src/gutter/gutter_alignment_test.dart` already pins for the gutter.

**Alternatives considered**:
- `TextStyle.backgroundColor` only — rejected (measured above).
- A `CustomPainter` that lays out its own text to find row boxes — rejected:
  duplicates the editor's layout and drifts from it (wrapping, RTL, folds).
- Per-line `Container`s in the gutter's `Table` — rejected: wrong side of the
  widget; the tint belongs to the text area.

## R2 — Where is the per-line index computed authoritatively?

**Decision**: it is not computed at all — `HiddenLineRanges.visibleLineNumbers`
already *is* the answer. The background layer iterates that list and hands the
builder each entry directly.

**Rationale**: the obvious place to derive an index is `SpanBuilder`, which
tracks `_visibleLineIndex` (`span_builder.dart:71`). Two hazards rule that out as
the *only* source:

- `_updateLineIndex` **clamps** to `code.lines.length - 1`, so a trailing
  newline reads back the last real line;
- a highlight node can carry several newlines at once (a block comment, a
  multi-line string), and `_buildNode` adds the whole count before building the
  node, so every line a multi-line node covers is attributed to its last line.

Both are live symptoms, not theoretical. Mapping the visible index back through
`code.hiddenLineRanges.recoverLineIndex(...)` fixes the coordinate space but not
the clamping or the multi-line attribution, because those happen before the
mapping.

`visibleLineNumbers` sidesteps all three: it is the list of full line indices the
editor actually renders, in order, produced by the same constructor the gutter
already trusts (`gutter.dart:190`). A layer that iterates it is correct by
construction — one row per visible line, keyed by its true full index — and it
needs no change to `SpanBuilder` at all. The multi-line-node hazard only exists
for an approach that styles spans; a row-per-visible-line layer never has a
"span that spans several lines".

**Alternative considered**: fixing `SpanBuilder` to attribute per node start
line (capturing the accumulator before `_updateLineIndex`) and driving the layer
from it — rejected as strictly more code and more risk for the same result,
while still needing the clamping fix.

## R2b — What happens on the no-language path?

**Decision**: nothing special is needed, and the layer works there too.

**Rationale**: `_createTextSpan` (`code_controller.dart:1287`) returns a single
`TextSpan(text: text, style: style)` when `_language == null`. That path cannot
carry a per-line style, which is why R1 rejects style-based backgrounds anyway.
A row layer does not read the span tree, so it is indifferent to the path — a
host with no language configured gets the same tinted rows as one with a
language. The plan's earlier "split the no-language span" task was therefore
dropped: it would have changed the default span tree to solve a problem the
chosen mechanism does not have.

**Alternative considered**: documenting the no-language path as unsupported —
rejected: hosts with no language are exactly the ones with no other way to mark
a line.

## R3 — What happens on the no-language path?

**Decision**: give that path line structure, but only when a builder is set.

**Rationale**: `_createTextSpan` (`code_controller.dart:1287`) returns a single
`TextSpan(text: text, style: style)` when `_language == null`. There is nothing to
attribute a background to, so a host with no language configured would silently
get nothing. Splitting it into per-line spans unconditionally would change the
span tree for every existing consumer, which the "default does not change"
decision forbids. Splitting it only when the builder is non-null keeps the
default byte-identical and makes the opt-in honest.

**Alternative considered**: document the no-language path as unsupported —
rejected: the issue is a host-integration request, and hosts that use no language
are exactly the ones with nothing to pin a background to.

## R4 — How is the requirement tested at the repo's level of assertion?

**Decision**: a widget test that asserts geometry, not a golden.

**Rationale**: existing background tests
(`test/src/code_field/search_result_highlighted_builder_test.dart`) assert span
structure, which cannot express "the tint is wider than the text". A widget test
can read the real layout: pump a `CodeField` with a builder that tints line 0,
then find the tinted row with `find.byWidgetPredicate` and compare
`tester.getSize(row).width` with the width of the text's own extent. A short line
whose tint is only as wide as its glyphs fails that assertion, which is exactly
the failure mode R1 warns about.

Golden tests were rejected: they need `golden_toolkit`, which is not a dependency,
and they are brittle across font/platform.

## R5 — Layering against search highlighting

**Decision**: the line tint is painted behind the text, so
`SearchResultHighlightedBuilder`'s per-match `backgroundColor`
(`search_result_highlighted_builder.dart:77-85`) is drawn on top of it and still
wins on matched runs.

**Rationale**: this is the layering the two features already imply — search
highlighting is a *finer* selection inside a line. A test with both a line tint
and an active search asserts the matched run's colour is the search colour and
the rest of the row is the line tint.

## Best practices consulted

- Flutter `TextStyle.background`/`backgroundColor` semantics (verified by
  measurement, R1).
- `LinkedScrollControllerGroup` usage already in the file, for linked scrollables.
- `CodeField`'s existing measurement cache pattern (`_rowHeightsForText` /
  `_rowHeightsForWidth`) for avoiding re-measurement on unrelated rebuilds.
