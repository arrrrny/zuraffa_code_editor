# Cycle Log: java-hash-strings-104

Engine: `zfa tdd run` unavailable (`ZFA_MISSING`, no `.zfa.json`) — the
red-green-refactor loop was driven by hand following the skill's fallback path.

## RED

Wrote `test/src/highlight/java_language_test.dart` (6 tests through
`CodeController`, 2 on the new seam) before touching `lib/`.

The first red was behavioural, not a compile error — the parser was missing but
the tests only needed `CodeController`, which already exists:

```
Expected: [
            (keyword, package),
            (class, A),
            (keyword, import),
            (string, """
multiline
"""),
            (function, public class A {)
          ]
  Actual: []
```

`Actual: []` is the filed defect: the whole document came back as one
unclassified node, so nothing classified at all.

## GREEN

1. Added `lib/src/highlight/mode_patches.dart` — the `"""…"""` string mode and
   the repaired copy of the `java` mode, behind `modeToRegister`.
2. `code_controller.dart:275` — `highlight.registerLanguage(_languageId, language)`
   became `highlight.registerLanguage(_languageId, modeToRegister(language))`.

Result: 8/8 green.

## Refactor

Three expectation lists were corrected to the measured classification before
the run went green. All three corrections were *additions* to my guesses, not
subtractions — I had predicted fewer classified runs than the parse produces
(`class` carries a trailing space and re-classifies its own keyword and title as
children, and `void m()` also yields `keyword void`, `title m`, `params ()`).
The shipped mode produces the same runs on clean input, pinned by the
`a document without the defects` test, so the additions are the truth and not
something the repair introduced.

## Behavioural red check

`git stash push lib/src/code_field/code_controller.dart` — the parser file and
the enum stay, only the registration line is reverted:

```
Expected: [ (keyword, package), (keyword, import), (keyword, public),
            (class, class A ), (keyword, class), (title, A),
            (keyword, private), (string, """…""" ) ]
  Actual: []
  Which: at location [0] is [] which shorter than expected
```

Three tests fail this way; the other five stay green because they do not depend
on the registration (the two `modeToRegister` unit tests, the
whole-source round-trip, and the `#`-inside-a-comment case, which never bails).

## Verification

See `test.md`.
