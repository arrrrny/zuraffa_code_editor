# Test list — trim the visible section's tag lines (#35)

The deliverable is behaviour: a tag line that carries nothing but the visible
section's tag disappears from the presented section, line break included.

`test/src/code/code_visible_section_tag_lines_test.dart` (12 tests, Code
level, no widget harness):

1. `the tag lines are cut from the presented section` — the acceptance
   criterion: `visibleText` is exactly the section's contents
   (`'  int x;\n'`), and `code.text` is untouched.
2. `the cut tag lines drop out of the visible line numbers` — `[3, 7]`: the
   content line and the trailing empty document line keep their numbers, the
   two tag lines lose theirs. Also pins
   `visibleText.split('\n').length == visibleLineNumbers.length` for this
   document, which is the row/number agreement the gutter's table is built
   from.
3. `a tag line that only holds the tag is cut, code and all` — leading
   whitespace before `//   [START s]` goes with it.
4. `a tag sharing its line with code is not cut` — `class A {// [START s]`
   keeps its line; only the comment is hidden, as before.
5. `only the visible section's own tags are cut` — a nested `[START inner]`
   inside `whole` keeps its remnants; it is contents, not scaffolding.
6. `a section with no start tag cuts its end tag`.
7. `the start tag is cut at the very top of the document` — offset 0 case of
   `_lineCarriesOnlyTheComment`.
8. `an end tag with no line break after it keeps its line` — there is nothing
   to cut, so the range stays the comment's own.
9. `an empty section presents nothing` — start and end tag on separate lines
   with no contents between them.
10. `a document without visible sections is untouched` — `// readonly` still
    hides only itself. `SingleLineComment.isReadonly` matches the *exact* word
    `readonly`, so `// endreadonly` is not a read-only marker at all; the
    document here uses a real one.
11. `the cut covers a CRLF line break too` — a single-line comment's content
    runs up to the `\n`, so the `\r` of a CRLF break belongs to the comment and
    the `\n` after it is the line break the cut consumes. Without that
    accident of the parser, a CRLF document would keep a `\r` remnant on each
    tag line; this pins it.
12. `the cut survives a selection round trip` — a selection over the whole
    presented section recovers to a full-document selection that cuts back to
    the very same visible selection. This is the regression risk of widening
    the range: every character after it moves, so the visible ↔ full mapping
    has to stay invertible.

Rewritten (not new) expectations, because the presentation changed:
`test/src/code_field/code_controller_visible_sections_test.dart`
(`Separate start no end`, `Separate start separate end`,
`Separate start trailing end`, `Trailing start separate end`,
`No start separate end`, `Newline after closing comment on the last line`) —
each now expects the trimmed text and the matching line numbers.
