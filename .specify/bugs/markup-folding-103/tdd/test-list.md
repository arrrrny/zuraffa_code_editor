# Test List: markup-folding-103

Derived from `.specify/bugs/markup-folding-103/spec.md`.
Engine: `zfa tdd plan` unavailable (`ZFA_MISSING`, no `.zfa.json`) — this list
was derived by hand following the skill's fallback path.

## Fault-detecting tests (must be RED before the fix)

| # | Test | Detects |
|---|------|---------|
| 1 | `test/src/folding/parsers/markup_parser_test.dart` → `a nested element folds into one markup block` | no block at all for XML (the filed bug) |
| 2 | same file → `nested elements produce nested blocks` | only the outermost element being seen |
| 3 | same file → `a self-closing element produces no block` | `<br/>` / `<img ... />` opening a block that never closes |
| 4 | same file → `the xml declaration and a comment produce no block` | `<?xml ?>` / `<!-- -->` counted as markup |
| 5 | same file → `an element on one line produces no block` | a same-line open/close pair producing a 1-line block |
| 6 | same file → `an unclosed element is an invalid block` | unclosed elements silently ignored |
| 7 | same file → `a stray closing tag is an invalid block` | stray `</x>` silently ignored |
| 8 | same file → `a < inside a comment or an attribute string is not markup` | text scanning instead of node-driven classification |
| 9 | `test/src/folding/parsers/parser_factory_test.dart` → `xml gets the markup parser` (new test in an existing file) | the factory not dispatching for xml |

## Characterisation tests (already GREEN — pin the unchanged paths)

| # | Test | Pins |
|---|------|------|
| 10 | `parsers/parser_factory_test.dart` (existing, 4 tests) | python/java/yaml/(anything else) dispatch unchanged |
| 11 | `parsers/java_parser_test.dart`, `python_parser_test.dart`, `indent_parser_test.dart`, `highlight_parser_go_test.dart`, `highlight_parser_scala_test.dart`, `fallback_foldable_block_parser_test.dart` (existing) | every other language's blocks unchanged |
| 12 | `folding/foldable_block_test.dart`, `folded_block_keeps_next_block_start_test.dart`, `folded_closing_line_test.dart` (existing) | the block lifecycle and gutter folding are untouched |
| 13 | `test/src/gutter/*` (existing) | the gutter still renders fold toggles from `foldableBlocks` |

## Cycle log

See `cycle-log.md`.
