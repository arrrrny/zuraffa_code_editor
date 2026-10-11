# Test List: java-hash-strings-104

Derived from `.specify/bugs/java-hash-strings-104/spec.md`.
Engine: `zfa tdd plan` unavailable (`ZFA_MISSING`, no `.zfa.json`) — this list
was derived by hand following the skill's fallback path.

## Fault-detecting tests (must be RED before the fix)

| # | Test | Detects |
|---|------|---------|
| 1 | `test/src/highlight/java_language_test.dart` → `classifies the document around a # and a triple-quoted string` | the whole document collapsing to one unclassified node |
| 2 | same file → `a # outside a string or a comment keeps the rest of the document highlighted` | the `illegal: "<\\/\|#"` bail |
| 3 | same file → `an unterminated triple-quoted string leaves the document highlighted up to it` | `"""` with no closer still losing the file |
| 4 | same file → `a document without the defects highlights exactly as the shipped mode does` | the repaired copy behaving differently from the shipped mode on clean input |

## Characterisation tests (already GREEN — pin the unchanged paths)

| # | Test | Pins |
|---|------|------|
| 5 | same file → `keeps every character of the source` | the repaired node tree still spans the source exactly |
| 6 | same file → `a # inside a string or a comment is not markup` | `#` inside a comment / string literal still classifying as before |
| 7 | `test/src/highlight/html_language_test.dart` (existing) | the `xml` mode's classification, the closest existing pin |
| 8 | `test/src/folding/parsers/java_parser_test.dart`, `python_parser_test.dart`, `indent_parser_test.dart`, `highlight_parser_*_test.dart` (existing) | the folding parsers, which read the same highlight nodes |
| 9 | `test/src/code_field/*` (existing) | the widget path, which shares `setLanguage` |

## Cycle log

See `cycle-log.md`.
