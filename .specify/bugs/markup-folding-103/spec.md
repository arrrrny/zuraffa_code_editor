# Spec: markup-folding-103

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/103
(upstream akvelon/flutter-code-editor#311).

## Requirement

A document highlighted as `xml` must expose its element structure as foldable
blocks, the way every brace language already does. Nesting elements fold;
self-closing elements, comments and processing instructions do not; malformed
nesting is reported, not silently ignored.

## Acceptance

- For `language: xml`, a nested element produces a `FoldableBlockType.markup`
  block spanning its opening tag's line to its closing tag's line.
- Several levels of nesting produce several blocks, inner blocks contained in
  outer ones.
- A self-closing element (`<br/>`, `<img src="x" />`) produces no block.
- `<?xml ... ?>` and `<!-- ... -->` produce no block.
- An element whose open and close are on the same line produces no block.
- An unclosed element produces an `InvalidFoldableBlock` rather than nothing.
- A stray closing tag produces an `InvalidFoldableBlock`.
- `<` inside a comment or an attribute string does not open or close a block.
- Python, Java, YAML and plank-text handling are unchanged — their existing
  suites stay green.

## Non-goals

- Highlight-layer behaviour, which is verified correct (see `assessment.md`).
- HTML void-element handling; `language: xml` is strict XML.
- Name-matched closing tags: the innermost open block is closed, as with
  brackets.
