# Test list: folding-hides-next-block-start

| # | Test | Type |
|---|---|---|
| 1 | the two touching blocks stay separate foldable blocks — `0..1`, `2..8`, `3..5`, `8..11` rather than one `2..11` | unit (red on master: `containsAllInOrder(['0..1', '2..8', '3..5', '8..11'])` — master produced `[0..1, 2..11, 3..5]`) |
| 2 | folding `factorial` (line 2) leaves line 8 visible — the text is `int factorial(int n){\n}void main(){` and line 8 has a row of its own | controller (red on master: `int factorial(int n){}void main(){` — glued, and `cutLineIndexIfVisible(8)` returned null) |
| 3 | the gutter and the editor agree on the row count after folding | controller (red on master: 5 visible lines against 6 rows) |
| 4 | `main` (line 8) still folds on its own — `}void main(){}` | controller |
| 5 | folding the outer block over the inner one round-trips losslessly back to the source | controller |
| 6 | the gutter still renders a fold toggle for the following block | widget (red on master: 2 toggles) |

Follow-up expectation updates, all pinned by the same new behaviour:

| # | Test | Change |
|---|---|---|
| 7 | `highlight_parser_go_test.dart` — "Multiline pair-character blocks", "Multiline imports", "Comments inside multiline imports" | the merged `union` blocks become the separate blocks they really are (`parentheses`/`braces`) |
| 8 | `highlight_parser_scala_test.dart` — "Multiline imports form braces foldable block" | `FB(0,3,imports)` → `FB(0,1,imports)` + `FB(1,3,braces)` |
| 9 | `java_parser_test.dart` — "All types of foldable blocks are recognized" | `FB(16,22,union)` → `FB(16,19,parentheses)` + `FB(19,22,braces)` |
| 10 | `java_parser_test.dart` — "Multiline comment after a brace", "Pair characters in a multiline that started at the end of a normal line", "Multiline comment that has a single-line comment after it…" | the same split, expressed in those shapes |
| 11 | `foldable_block_test.dart` — "Intersecting blocks" | the expected list gains the blocks that are kept apart |
