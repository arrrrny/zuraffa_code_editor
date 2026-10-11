# Bug Assessment: Java highlighting breaks on `#` outside strings and on triple-quoted strings

- **Slug**: java-hash-strings-104
- **Created**: 2026-10-11
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/104
- **Upstream**: https://github.com/akvelon/flutter-code-editor/issues/42
- **Verdict**: **valid, reproduced, root-caused and fixed.** Both reported
  defects are real, both live in `highlight` 0.7.0's `java` mode, and they are
  two routes into the same failure.
- **Severity**: medium

## Symptom as filed

One `#` anywhere outside a comment or a string literal, or one triple-quoted
string literal, and the Java file loses its highlighting.

## Reproduction

```dart
final controller = CodeController(
  text: 'public class A {\n}\n#\n',
  language: java,
);
controller.code.highlighted!.nodes
// → one node, className null, value = the entire document
```

The same happens for `String s = """\nmultiline\n""";`.

## Measurement (master, before the fix)

`highlight.parse(source, language: 'java')`, `null` `top` meaning the parse
aborted:

| source | aborted | relevance | nodes |
| ------ | ------- | --------- | ----- |
| `public class A {\n}\n` | no | 3 | 5, classes `[-, keyword, -, class, -]` |
| `public class A {\n}\n#\n` | **yes** | 0 | 1, classes `[-]` |
| `#\n` | no¹ | 0 | 1 |
| `// #\npublic class A {}` | no | 4 | 7 |
| `String s = "#";` | no | 1 | 3 |
| `String s = "x";` | no | 1 | 3 |
| `String s = "";` | no | 1 | 3 |
| `String s = """;` | **yes** | 0 | 1 |
| `String s = """\nmultiline\n""";` | **yes** | 0 | 1 |
| `String s = "a\nb";` | **yes** | 0 | 1 |
| `</div>\n` | no¹ | 0 | 1 |

¹ `nodes=1, relevance=0` here is not a bail — a document with no java
construct in it legitimately comes back as one plain node. The bail signature
is `Result.top == null`, and these have a `top`. The distinction matters: it is
what separates "nothing to highlight" from "lost the highlighting".

`#` inside a comment or a string is fine, because those modes match it first.

## Root cause

`_parse` throws on an illegal lexeme and catches its own throw
(`highlight-0.7.0/lib/src/highlight.dart:442-491`):

```dart
if (_isIllegal(lexeme, top)) {
  throw 'Illegal lexeme "' + lexeme + '" ...';
}
...
} catch (e) {
  if (e is String && e.startsWith('Illegal')) {
    return Result(relevance: 0, nodes: [Node(value: source)]);
  } else {
    rethrow;
  }
}
```

So a bail is not an exception the caller ever sees — it silently swaps the whole
document for one unclassified node. Three things can trigger it in Java:

1. **The mode's top-level `illegal` regex is `<\/|#`**
   (`highlight-0.7.0/lib/languages/java.dart`). `_compileMode` builds `illegalRe`
   from it and also adds it to the mode's terminators, so a `#` or a `</` that
   is not already inside a comment or a string throws.
2. **`QUOTE_STRING_MODE` declares `illegal: '\n'`.** A raw newline inside a
   `"..."` throws, which is exactly what a triple-quoted literal produces: with
   no triple-quote mode, the third `"` of `"""` opens an ordinary string whose
   content runs to a newline.
3. **`APOS_STRING_MODE` declares the same `illegal: '\n'`** for `'...'`, reached
   the same way.

Item 3 is the same defect as item 2 with a different quote character; the
reported reproduction only uses `"""`, and the patch fixes `"""` (see
Non-goals).

## Why the reporter's own example looks like "the document structure is lost"

`relevance` drops to 0 and `nodes` collapses to one, so the span builder has
nothing to classify and every character renders in the default colour. The
fold path survives — `HighlightFoldableBlockParser` scans the single node's
value for brackets — which is why the file still folds but no longer
highlights.

## Proposed remediation

Register a repaired copy of the `java` mode with the highlighter:

- drop the top-level `illegal` regex, so a `#` or a `</` is ordinary text;
- add a `"""…"""` string mode listed **ahead** of the single-quoted string
  modes, so the triple quote is matched before a lone `"` is.

The seam is `CodeController.setLanguage`, which already registers the supplied
mode under a synthetic key (`code_controller.dart:274-275`). Handing the
repaired copy to `highlight.registerLanguage` there keeps the caller's own
`Mode` everywhere else — `controller.language`, `autocompleter.mode` and
`SingleLineComments.byMode` all still key on the original.

A copy rather than the shipped mode with a field cleared, because `Mode`
caches the regexes compiled from `illegal` and `contains` on the first parse:
editing the shipped mode after it has been compiled would leave the stale
regexes in place, and the defect would survive the fix.

## Risks & Considerations

- **Only java is affected.** `modeToRegister` hands back every other mode
  identity-equal, and the dispatch is an identity check on the `java` Mode
  object, so a mode a caller built themselves is untouched.
- **A `#` in a Java comment or a string still highlights as before**, because
  those modes match it before the top-level terminators see it.
- **Widening the terminator set is deliberate.** With `#` gone from `illegal`
  it is also gone from the terminators, so `#` is tokenised as ordinary text
  rather than as a terminator. That is the intended reading.
- **A `highlight` upgrade may make the repair unnecessary.** If a future
  release drops `illegal: '<\/|#'` or adds a triple-quote mode, the copy
  becomes a no-op and the tests still pin the classification, so the removal
  is a safe follow-up rather than a required one.
- The copy shares the shipped mode's child `Mode` objects, which the
  highlighter compiles on first use. Compiling is idempotent and is what a
  direct `highlight.parse(x, language: 'java')` does anyway, so a consumer
  using `highlight` directly is unaffected.

## Non-goals

- **A raw newline inside an ordinary `"..."` still bails.** That is a Java
  syntax error, not a defect in the mode's intent, and the issue does not
  report it. Fixing it would mean dropping `\n` from `QUOTE_STRING_MODE`'s
  `illegal`, which turns an unterminated string into one that swallows the rest
  of the document instead of the document going plain — a trade with no clear
  winner, deliberately not taken here.
- **`'...'` triple quotes.** Java has no such literal.
- **Python (`def fn()` without a trailing `:`) and Scala multiline strings**,
  the other two items of upstream #42. Separate issues; the Python one is
  already covered by `PythonFallbackFoldableBlockParser` on the folding side.
- **Broadening the patch to other languages** whose modes declare the same
  `illegal` patterns.
