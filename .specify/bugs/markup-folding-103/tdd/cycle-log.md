# Cycle Log: markup-folding-103

Engine: `zfa tdd run` unavailable (`ZFA_MISSING`, no `.zfa.json`) — the
red-green-refactor loop was driven by hand following the skill's fallback path.

## RED

Added `test/src/folding/parsers/markup_parser_test.dart` (9 tests) and the
`xml gets the markup parser` test to `test/src/folding/parsers/parser_factory_test.dart`.

Result — **compilation failure**, which is the honest red for a missing
feature:

```
test/src/folding/parsers/markup_parser_test.dart:8:8: Error: Error when reading
'lib/src/folding/parsers/markup.dart': No such file or directory
test/src/folding/parsers/markup_parser_test.dart:23:18: Error: Method not found:
'MarkupFoldableBlockParser'
test/src/folding/parsers/markup_parser_test.dart:47:27: Error: Member not found:
'markup'
```

Three independent errors: no parser file, no parser class, no enum value.

## GREEN

1. Added `markup` to `FoldableBlockType`
   (`lib/src/folding/foldable_block_type.dart`).
2. Added `lib/src/folding/parsers/markup.dart` with
   `MarkupFoldableBlockParser`.
3. Added `if (mode == xml) return MarkupFoldableBlockParser();` to
   `FoldableBlockParserFactory` (`lib/src/folding/parsers/parser_factory.dart`).

Intermediate failure on the first green attempt: `highlighted.forEachNode`
was not defined for `Result` — the extension lives in
`lib/src/highlight/result.dart`, so the parser gained that import.

Result: 14/14 green in the two touched files, then 11/11 with the
`CodeController` end-to-end case added alongside.

## Refactor

- No refactor was needed. The measurement table in `assessment.md` was taken
  before the test file was written, so no expectations were adjusted to fit the
  implementation.

## Verification

See `test.md`.
