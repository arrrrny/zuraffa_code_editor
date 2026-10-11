# Bug Assessment: HTML/XML highlighting is broken

- **Slug**: markup-folding-103
- **Created**: 2026-10-11
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/103
- **Upstream**: https://github.com/akvelon/flutter-code-editor/issues/311
- **Verdict**: **half reproducible. The highlighting claim does not reproduce;
  "the document structure is lost" does, and it lives in the folding layer, not
  in `lib/src/highlight/` as filed.**
- **Severity**: medium

## Symptom as filed

> With `language: xml` the elements are not highlighted and the document
> structure is lost.

Two claims. The first is wrong; the second is right and points at a different
file than the reporter guessed.

## Claim 1 — "the elements are not highlighted": NOT REPRODUCIBLE

Driven through the real path on master, XML highlighting is correct:

- `highlight.parse(src, language: 'xml')` classifies a realistic Android layout
  into `meta` (`<?xml ...?>`), `comment` (`<!-- ... -->`) and `tag` nodes whose
  children carry `name`, `attr` and `string`.
  Observed class set: `{meta, comment, tag, name, attr, string}`.
- Driving `SpanBuilder` with `vsTheme` on the same document yields six distinct
  colours — `#ff2b91af` for `meta`, `#ff008000` for `comment`, `#ff0000ff` for
  `tag`/`name`, `#ffff0000` for `attr`, `#ffa31515` for `string`.
- `CodeController._createTextSpan` (`lib/src/code_field/code_controller.dart`)
  builds its spans with exactly that `SpanBuilder`, so the widget path is the
  same path and cannot differ.

So there is no highlight-layer defect to fix here. The `Where it lives` field
(`lib/src/highlight/`) is a red herring.

Two probe traps worth recording, both of which produced false "not highlighted"
readings before they were caught:

- `tester.widgetList<RichText>(...)` .first returns the **gutter's** number
  `Text`, not the code area.
- Feeding Java source to an `xml` mode legitimately highlights nothing.

## Claim 2 — "the document structure is lost": REPRODUCIBLE, in the fold layer

Structure in this editor means foldable blocks (the gutter chevrons). Measured
on master, same probe, same document:

```dart
final code = CodeController(text: xmlSrc, language: xml).code;
code.foldableBlocks // []   <- java gives [0-3, 1-2] on 'class A { void m() { } }'
code.invalidBlocks // []
```

`0` blocks for XML where java produces 2. Note `invalidBlocks` is also empty:
nothing is even detected as malformed, because nothing is detected at all.

## Root cause

`FoldableBlockParserFactory.provideParser`
(`lib/src/folding/parsers/parser_factory.dart:13`) special-cases exactly three
languages:

| language | parser |
| -------- | ------ |
| python | `PythonFoldableBlockParser` |
| java | `JavaFoldableBlockParser` |
| yaml | `IndentFoldableBlockParser` |
| everything else | `HighlightFoldableBlockParser` |

`HighlightFoldableBlockParser` opens blocks on `(`, `[`, `{` only
(`lib/src/folding/parsers/highlight.dart:147-170`). Markup nests on
`<tag>`/`</tag>`, so for XML the fallback parser sees no bracket ever, opens
nothing, and produces no blocks. The document has no structure *in the editor's
sense* even though it has plenty structurally.

## Proposed remediation

Give markup its own parser and dispatch to it for `xml`, following the existing
java/python/yaml pattern exactly:

- add `FoldableBlockType.markup`;
- add `lib/src/folding/parsers/markup.dart` with `MarkupFoldableBlockParser`,
  driven by `highlighted.forEachNode` so `<` inside a comment, CDATA, processing
  instruction or attribute string can never look like an element;
- `if (mode == xml) return MarkupFoldableBlockParser();` in the factory.

Tag classification, measured from `forEachNode` (first/last child values):

| shape | children | verdict |
| ----- | -------- | ------- |
| `<LinearLayout ...>` | first `<`, last `>` (11 children) | opening |
| `<FrameLayout>` | first `<`, last `>` (3 children) | opening |
| `<TextView ... />` | first `<`, last ` />` (7 children) | self-closing |
| `<Button ... />` | first `<`, last ` />` (7 children) | self-closing |
| `</FrameLayout>` | first `</`, last `>` (3 children) | closing |
| `</LinearLayout>` | first `</`, last `>` (3 children) | closing |

Opening pushes a block at the tag's start line, closing pops the innermost open
block with no name matching (same strategy the generic parser uses for
brackets). `AbstractFoldableBlockParser.endBlock` already drops a block whose
start and end are the same line, so `<a>text</a>` on one line correctly folds
to nothing. Unclosed elements become `InvalidFoldableBlock` records, exactly
like unclosed braces. No void-element list: `language: xml` is strict XML, so
an unclosed `<br>` should be reported as invalid rather than silently forgiven.

## Non-goals

- Highlight-layer changes. Verified correct; changing them would be churn.
- HTML. `language: html` in highlight 0.7.0 is an alias of `xml`, so it comes
  along for free, but no HTML-specific void-element rules are added here.
- Broadening dispatch to anything else. Other languages that fall through to
  the bracket parser are separate issues.

## Risks & Considerations

- Only the `xml` path changes. Python, java, yaml and everything that currently
  reaches `HighlightFoldableBlockParser` keep their exact parser, pinned by the
  existing folding suites.
- Because a malformed nesting now yields `InvalidFoldableBlock` records instead
  of silence, the error highlighting of genuinely broken XML gets more accurate,
  which is a side benefit rather than a behaviour regression.
