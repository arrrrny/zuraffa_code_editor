# Fix: XML documents get foldable blocks again (#103)

Closes #103 (upstream `akvelon/flutter-code-editor#311`).

## What was wrong

The report has two claims. The first does not reproduce; the second does, and
it lives in a different layer than the reporter guessed.

**"the elements are not highlighted" — not reproducible.** Driven through the
real path on master, `highlight.parse(src, language: 'xml')` classifies a
document into `meta` (`<?xml ...?>`), `comment` (`<!-- ... -->`) and `tag` nodes
whose children carry `name`, `attr` and `string` — the observed class set is
`{meta, comment, tag, name, attr, string}`. Driving `SpanBuilder` with `vsTheme`
over those nodes yields six distinct colours, and
`CodeController._createTextSpan` builds its spans with exactly that
`SpanBuilder`. So the widget path is the same path and cannot differ. The filed
`Where it lives` (`lib/src/highlight/`) is a red herring.

**"the document structure is lost" — reproducible, in the fold layer.**
Structure here means foldable blocks, the gutter's chevrons. Measured on master:

```dart
CodeController(text: xmlSrc, language: xml).code.foldableBlocks // []
CodeController(text: 'class A {\n  void m() {\n  }\n}\n', language: java)
    .code.foldableBlocks                                        // [0-3, 1-2]
```

`[]` for XML where java yields two brace blocks. Note `invalidBlocks` is empty
too: nothing is even reported as malformed, because nothing is detected at all.

## Root cause

`FoldableBlockParserFactory.provideParser` special-cases three languages:

| language | parser |
|---|---|
| python | `PythonFoldableBlockParser` |
| java | `JavaFoldableBlockParser` |
| yaml | `IndentFoldableBlockParser` |
| everything else | `HighlightFoldableBlockParser` |

`HighlightFoldableBlockParser` opens blocks on `(`, `[` and `{` only.
Markup nests on `<tag>`/`</tag>`, so for XML no bracket ever appears, no block
is ever opened, and the document has no structure in the editor's sense.

## The fix

- `FoldableBlockType.markup`
- `lib/src/folding/parsers/markup.dart` — `MarkupFoldableBlockParser`
- `if (mode == xml) return MarkupFoldableBlockParser();` in the factory,
  matching the existing java/python/yaml dispatch exactly

The parser is driven by `highlighted.forEachNode`, not a text scan, so a `<`
inside a comment, a CDATA section, a processing instruction or an attribute
value can never be mistaken for an element. Tag shape is read off the node's
children — all measured from `forEachNode` on master:

| shape | children | verdict |
|---|---|---|
| `<LinearLayout ...>` | first `<`, last `>` (11) | opening |
| `<FrameLayout>` | first `<`, last `>` (3) | opening |
| `<TextView ... />` | first `<`, last ` />` (7) | self-closing |
| `<Button ... />` | first `<`, last ` />` (7) | self-closing |
| `</FrameLayout>` | first `</`, last `>` (3) | closing |

Opening pushes a block at the tag's start line; closing pops the innermost open
block with **no name matching**, which is what the generic parser does for
brackets. `AbstractFoldableBlockParser.endBlock` already drops a block whose
start and end are the same line, so `<a>text</a>` on one line folds to nothing.
Unclosed elements and stray closing tags become `InvalidFoldableBlock` records,
exactly like unclosed braces.

## What is deliberately unchanged

- **The highlight layer.** Verified correct; changing it would be churn.
- **Python, java, yaml and everything that reaches
  `HighlightFoldableBlockParser`.** Their parser and their suites are untouched
  and green.
- **No HTML void-element list.** `language: xml` is strict XML, so an unclosed
  `<br>` is reported as invalid rather than silently forgiven — the same rule
  an unclosed brace already follows.
- **Dispatch stays identity-based** on `Mode`, as it is today. `Mode` defines
  no `operator==`, so `mode == xml` is identity, and the factory receives the
  exact `Mode` the caller handed to `CodeController.language`.

## Tests

`test/src/folding/parsers/markup_parser_test.dart` (new, 11 tests) and one new
case in `test/src/folding/parsers/parser_factory_test.dart`:

| test | red without the fix? |
|---|---|
| `a nested element folds into one markup block` | **yes** — no file, no class, no enum value |
| `nested elements produce nested blocks` | **yes** |
| `a self-closing element produces no block` | **yes** |
| `the xml declaration and a comment produce no block` | **yes** |
| `an element on one line produces no block` | **yes** |
| `an unclosed element is an invalid block` | **yes** |
| `a stray closing tag is an invalid block` | **yes** |
| `a < inside a comment or an attribute string is not markup` | **yes** |
| `a document without markup produces nothing at all` | green either way |
| `xml gets the markup parser` (factory) | **yes** |
| `an android layout gets a fold toggle for each nesting element` (through `CodeController`) | **yes** — this is the issue's own scenario |

The red was a compilation failure, which is the honest red for a missing
feature: `Error when reading 'lib/src/folding/parsers/markup.dart'`,
`Method not found: 'MarkupFoldableBlockParser'`, `Member not found: 'markup'`.

## Verification

- `flutter test` — **765/765 passing** (754 on master + 11 new tests)
- `dart analyze` — clean; `dart format` — clean
- Coverage gate — **100.00%**, no new exemption added: every line of
  `markup.dart` is reachable and covered

Spec/assessment/TDD chain: `.specify/bugs/markup-folding-103/`.
