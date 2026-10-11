# Fix: markup-folding-103

## Root cause

`FoldableBlockParserFactory.provideParser`
(`lib/src/folding/parsers/parser_factory.dart`) resolved a language `Mode` to a
parser, and only three languages had a parser of their own — python → indent,
java → brackets, yaml → indentation. Everything else fell through to
`HighlightFoldableBlockParser`, which opens blocks on `(`, `[` and `{` alone.
XML nests on `<tag>`/`</tag>`, so the fallback never opened a block, and
`CodeController(text: ..., language: xml).code.foldableBlocks` came back empty
while java returned two brace blocks on a three-line class.

## Changes

| file | change |
|---|---|
| `lib/src/folding/foldable_block_type.dart` | added `markup` |
| `lib/src/folding/parsers/markup.dart` | new — `MarkupFoldableBlockParser` |
| `lib/src/folding/parsers/parser_factory.dart` | `if (mode == xml)` dispatch |
| `test/src/folding/parsers/markup_parser_test.dart` | new — 11 tests |
| `test/src/folding/parsers/parser_factory_test.dart` | `xml gets the markup parser` |
| `CHANGELOG.md` | Unreleased → Fixed |

## The parser

`MarkupFoldableBlockParser` walks `highlighted.forEachNode` and reacts to `tag`
nodes only, classifying each from its first and last child values:

- first child `</` → closing tag → `endBlock(lineIndex, markup)`
- first child `<` and last child ending in `/>` → self-closing → nothing
- first child `<` → opening tag → `startBlock(lineIndex, markup)`

The line index is the one `forEachNode` reports for the node, which is the line
the tag starts on. Closing tags pop the innermost open markup block, with no
name matching — the same strategy the generic parser applies to brackets, so
malformed nesting degrades into `InvalidFoldableBlock` records rather than
silently vanishing.

Because classification reads highlight's nodes rather than the raw text, a `<`
inside a comment, a CDATA section, a processing instruction or an attribute
string is never mistaken for an element — the bug a naive
`text.contains('<')` scanner would have.

## Notes

- `serviceCommentsSources` is part of the parser interface but is not consulted:
  comments are not markup blocks, and `<!-- -->` produces nothing by design.
- `FoldableBlockType` has no exhaustive switch over it anywhere in `lib/` or
  `test/`, so adding the value is additive. `FoldableBlock.join` maps any join
  involving a non-import block to `union`, which is existing behaviour and not
  markup-specific.
