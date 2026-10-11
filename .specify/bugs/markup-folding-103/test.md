# Test: markup-folding-103

## Full suite

`flutter test` on `bug/markup-folding-103` rebased onto `0efb5fc` (#128 merged):

```
03:30 +769: .../horizontal_scroll_behaviour_test.dart: the code area leaves it
             alone when there is nothing to scroll wrap: true reflows instead of
             scrolling
03:37 +769: All tests passed!
```

**769 tests, 0 failures** (758 on master + 11 new).

## New tests

`test/src/folding/parsers/markup_parser_test.dart` (11 tests) and one new case
in `test/src/folding/parsers/parser_factory_test.dart`:

| Test | Result |
|---|---|
| `a nested element folds into one markup block` | green (red without the fix) |
| `nested elements produce nested blocks` | green (red without the fix) |
| `a self-closing element produces no block` | green (red without the fix) |
| `the xml declaration and a comment produce no block` | green (red without the fix) |
| `an element on one line produces no block` | green (red without the fix) |
| `an unclosed element is an invalid block` | green (red without the fix) |
| `a stray closing tag is an invalid block` | green (red without the fix) |
| `a < inside a comment or an attribute string is not markup` | green (red without the fix) |
| `a document without markup produces nothing at all` | green (characterisation — green on both trees) |
| `an android layout gets a fold toggle for each nesting element` (through `CodeController`) | green (red without the fix) |
| `xml gets the markup parser` (factory) | green (red without the fix) |

## Red check

The first red was a **compilation failure**, which is the honest red for a
feature that does not exist yet — there was no file, no class and no enum value
to call:

```
test/src/folding/parsers/markup_parser_test.dart:8:8: Error: Error when reading
'lib/src/folding/parsers/markup.dart': No such file or directory
test/src/folding/parsers/markup_parser_test.dart:23:18: Error: Method not found:
'MarkupFoldableBlockParser'
test/src/folding/parsers/markup_parser_test.dart:47:27: Error: Member not found:
'markup'
test/src/folding/parsers/parser_factory_test.dart: …: Error: Member not found: 'MarkupFoldableBlockParser'
```

See `tdd/cycle-log.md` for that step.

## Behavioural red check

Stashing the parser alone leaves the tests compiling, so to see the *behavioural*
red the factory dispatch was stashed instead
(`git stash push lib/src/folding/parsers/parser_factory.dart`) — the parser file
and the enum stayed, only the `if (mode == xml)` line went away:

```
parser_factory_test.dart: FoldableBlockParserFactory xml gets the markup parser [E]
  Expected: <Instance of 'MarkupFoldableBlockParser'>
    Actual: <Instance of 'HighlightFoldableBlockParser'>

markup_parser_test.dart: ...through CodeController an android layout gets a fold
toggle for each nesting element [E]
  Expected: [
              FoldableBlock:FoldableBlock(2, 13, FoldableBlockType.markup),
              FoldableBlock:FoldableBlock(9, 11, FoldableBlockType.markup)
            ]
    Actual: []
```

`Actual: []` is the issue, exactly as filed: no foldable blocks for XML.
The nine parser-level tests stay green in that run, which is the expected
split — they drive `MarkupFoldableBlockParser` directly and do not depend on the
dispatch; the factory test and the `CodeController` test are the two that
guard it.

## Static checks

- `dart analyze` — `No issues found!`
- `dart format --output=none --set-exit-if-changed lib test` — clean

## Coverage gate

```
zuraffa_code_editor line coverage: 100.00% (3374/3374 lines over 106 files)
excluded individual lines (see EXEMPT_LINES): 13
Coverage gate: 100.00% >= 100.00% — OK
```

On master the same gate reports 100.00% (3371/3371 over 105 files): the parser
adds one file and three covered lines, and no new exemption was needed. Every
line of `markup.dart` is reachable and covered — the guards on
`node.className`, `children`, `opener` and `closer` are all single-line
expressions that the new tests exercise, so there are no fallback branches
left to exempt.
