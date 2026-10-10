# Decision: yes — a visible section trims its own tag lines (#35)

**Issue:** [arrrrny/zuraffa_code_editor#35](https://github.com/arrrrny/zuraffa_code_editor/issues/35)
— synced from upstream `akvelon/flutter-code-editor#109`.
**Label:** `spec`

## Question

> Should a visible section trim the blank lines that remain around it?

Upstream `akvelon/flutter-code-editor#109` asks exactly this: what a reader of
a `[START name]` / `[END name]` section wants to read is the section's
*contents*, and today they get the section's contents wrapped in the leftovers
of the two scaffolding comments that mark it.

## What is already cut

Two things around a visible section were already hidden before this change:

1. the document before the section's first line and after its last line
   (`_visibleSectionsToHiddenRanges`' `beginning` / `ending` ranges), and
2. each service comment's own text, via `_commentsToHiddenRanges`.

What survived was the *shell* of each tag line: the whitespace that preceded
the tag comment, and the line break that followed it. A section whose tags sit
on lines of their own therefore rendered with a blank line before and after
its contents, and the gutter still carried a number for each of those two
lines.

## Decision: cut the whole tag line, when the line is only the tag

The change widens the hidden range of a service comment that is one of the
*visible* section's own tag lines, so the range now covers the entire line:
the whitespace before the comment **and** the line break after it. The
presented section renders flush against its contents.

The cut is deliberately narrow. It applies only when **all** of these hold:

- the section is the visible one (`visibleSection != null`) — a document with
  no visible section is byte-for-byte unchanged;
- the comment is one of that section's own two tag lines (`[START name]` /
  `[END name]`), not some other section's tag that happens to fall inside it.
  The tag is recognized by content — the same `startRe` / `endRe` patterns
  that define the section, matched against the section's own name — and not
  by the line it sits on. A first cut of this change gated on line position,
  and the pool review caught the hole: a section that was never started
  reports `firstLine == 0` as a document default, so line 0 is not
  necessarily a tag line, and any service comment that merely sits there
  (`// readonly`, another section's tag) was cut whole with it. Keeping the
  patterns on the parser rather than re-deriving them here is what makes the
  whitespace variants (`[ START s ]`) behave like the tags the parser built
  the section from;
- the tag line carries nothing but the comment — a tag sharing its line with
  code (`class A {// [START s]`) keeps its line, because the code before the
  comment belongs to the section and must stay reachable;
- there is a line break after the comment — an end tag on the last line of a
  document with no trailing newline has none to cut;
- the section's start and end tags are on different lines — a start and an end
  tag on one line describe an empty section, and an empty line is not
  scaffolding worth a special case.

A section with no start tag cuts its end tag alone; the same rule covers it,
because the guard is per-comment rather than per-section.

## What this visibly changes

Only the presentation of a visible section. Six pre-existing tests in
`test/src/code_field/code_controller_visible_sections_test.dart` encoded the
old shell-of-the-tag-line presentation and were rewritten to the trimmed form;
their line-number expectations moved with it, because a cut tag line no longer
has a row to label. Nothing else in the repository changed behaviour: the read
path, the edit path, folding and the search path are untouched, and a document
with no visible section produces identical `HiddenRanges` to before.

## Out of scope, recorded honestly

- **The trailing empty row has no number.** When a section's last visible line
  ends with a visible line break, the editor renders one more (empty) row than
  the gutter has numbers, because `HiddenLineRanges` numbers document lines
  and that extra row is not a document line. This is pre-existing — it happens
  on `master` for the trailing-end sections too (`[1, 2, 3]` over four rows) —
  and this change keeps the same shape (`[2, 3]` over three rows). Fixing it
  means deciding what the number of an empty trailing row *is*, which is a
  gutter policy question, not a tag-trimming one.
- **A tag comment that is not a section tag.** `// readonly`, `// fold`, and
  the doc-editor's own service markers still hide only their own text, exactly
  as before: `_isVisibleSectionTagLine` is the only gate into the wider range.
- **Upstream's edit-path complaints.** Upstream #109 also asks whether a user
  should be able to type onto a tag line and see it reappear. The visible
  section makes the whole document read-only, so no edit path exists in
  presentation mode; that half of the issue needs a presentation-mode editing
  model and is a separate feature.
