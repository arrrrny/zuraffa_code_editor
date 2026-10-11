# Fix: a `#` and triple-quoted strings no longer cost a Java file its highlighting (#104)

Closes #104 (upstream `akvelon/flutter-code-editor#42`).

## What was wrong

One `#` outside a comment or a string literal and the whole Java file goes
plain. So does one triple-quoted string literal.

Both are the same failure reached two ways. `highlight` 0.7.0's `_parse` throws
on an illegal lexeme, catches its own throw, and hands back the entire document
as one unclassified node (`highlight-0.7.0/lib/src/highlight.dart:442-491`):

```dart
if (_isIllegal(lexeme, top)) {
  throw 'Illegal lexeme "' + lexeme + '" for mode ...';
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

A bail is therefore not an exception the caller ever sees — the parse just
silently returns nothing useful. Measured on master, through
`CodeController(text:, language: java)`:

| source | `top` | relevance | nodes | classes |
|---|---|---|---|---|
| `public class A {\n}\n` | mode | 3 | 5 | `[-, keyword, -, class, -]` |
| `public class A {\n}\n#\n` | **null** | 0 | 1 | `[-]` |
| `String s = "x";` | mode | 1 | 3 | `[-, string, -]` |
| `String s = """\nmultiline\n""";` | **null** | 0 | 1 | `[-]` |
| `String s = "a\nb";` | **null** | 0 | 1 | `[-]` |
| `// #\npublic class A {}` | mode | 4 | 7 | `[-, comment, -, keyword, -, class, -]` |

Note the distinction that makes the measurement readable: `nodes=1,
relevance=0` also happens for a document that has **no java construct in it**,
which is not a bail. The bail signature is `Result.top == null`.

The three triggers in the `java` mode:

1. the top-level `illegal` regex is `<\/|#` — so `#` and a stray `</` throw,
   unless a comment or a string mode matched them first;
2. `QUOTE_STRING_MODE` declares `illegal: '\n'`, and with no triple-quote mode
   the third `"` of `"""` opens an ordinary string that hits a newline;
3. `APOS_STRING_MODE` declares the same, reached the same way with `'`.

The fold path survives all of this — `HighlightFoldableBlockParser` scans the
single node's value for brackets — which is why the file still folds but stops
highlighting.

## The fix

`lib/src/highlight/mode_patches.dart`:

```dart
final _tripleQuotedString = Mode(
  className: 'string',
  begin: '"""',
  end: '"""',
  relevance: 0,
);

final _patchedJava = Mode(
  refs: java.refs,
  aliases: java.aliases,
  keywords: java.keywords,
  contains: [_tripleQuotedString, ...java.contains ?? const <Mode?>[]],
);

Mode modeToRegister(Mode mode) => mode == java ? _patchedJava : mode;
```

`lib/src/code_field/code_controller.dart:275`:

```diff
-highlight.registerLanguage(_languageId, language);
+highlight.registerLanguage(_languageId, modeToRegister(language));
```

Three decisions worth reviewing:

- **A copy, not the shipped mode with `illegal` cleared.** `Mode` caches the
  regexes compiled from `illegal` and `contains` on the first parse
  (`_compileMode` sets `illegalRe` and `terminators`, then `compiled = true`).
  Clearing the field on the shipped mode after it has been compiled leaves the
  stale regexes in place and the defect alive — and whether it has been
  compiled depends on whether anything else in the process parsed `java`
  first. The copy is always fresh, so it is always recompiled.
- **The triple-quote mode is listed first.** The mode's terminators are the
  `contains` begins joined by `|` in order, and Dart alternation is
  leftmost-first, so `"""` is matched before a lone `"` can be.
- **The seam is `setLanguage`, not the parse.** `CodeController` already
  registers the supplied mode under a synthetic key
  (`_languageId = language.hashCode.toString()`), so handing the repaired copy
  to `registerLanguage` there is the same seam — and `controller.language`,
  `autocompleter.mode` and `SingleLineComments.byMode` all still key on the
  mode the caller supplied.

## What is deliberately unchanged

- **Every language other than java.** `modeToRegister` hands back any other
  mode identity-equal, and the check is identity (`Mode` defines no
  `operator==`), so a mode a caller built themselves is untouched. Pinned.
- **A raw newline inside an ordinary `"..."` still bails.** That is a Java
  syntax error, not a defect in the mode's intent, and the issue does not
  report it. Removing `\n` from `QUOTE_STRING_MODE`'s `illegal` would turn an
  unterminated string into one that swallows the rest of the document instead
  of the document going plain — a trade with no clear winner, deliberately not
  taken.
- **`'''` literals**, which Java does not have.
- **Python and Scala**, the other two items of upstream #42. Separate issues;
  the Python one is already covered on the folding side by
  `PythonFallbackFoldableBlockParser`.

## Tests

`test/src/highlight/java_language_test.dart` (new, 8 tests):

| test | red without the fix? |
|---|---|
| `classifies the document around a # and a triple-quoted string` | **yes** — `Actual: []` |
| `a # outside a string or a comment keeps the rest of the document highlighted` | **yes** — `Actual: []` |
| `an unterminated triple-quoted string leaves the document highlighted up to it` | **yes** — `Actual: []` |
| `a document without the defects highlights exactly as the shipped mode does` | **yes** |
| `keeps every character of the source` | no (round-trip holds either way) |
| `a # inside a string or a comment is not markup` | no (never bails) |
| `hands back the java mode it was given a repaired copy for` | no (unit seam) |
| `leaves every other mode exactly as it was supplied` | no (unit seam) |

Red check with `git stash push lib/src/code_field/code_controller.dart` — the
parser file stays, only the registration line goes away:

```
Expected: [ (keyword, package), (keyword, import), (keyword, public),
            (class, class A ), (keyword, class), (title, A),
            (keyword, private), (string, """…""" ) ]
  Actual: []
```

## Verification

- `flutter test` — **766/766 passing** (758 on master + 8 new)
- `dart analyze` — clean; `dart format` — clean
- Coverage gate — 100.00%

Spec/assessment/TDD chain: `.specify/bugs/java-hash-strings-104/`.
README: a `#### Java: # and triple-quoted strings` subsection under Syntax
Highlighting.
