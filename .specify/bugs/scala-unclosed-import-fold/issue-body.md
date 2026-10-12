## Symptom

With an unclosed Scala selective-import brace (`import users.{` with no closing `}`), the first real block after the import is swallowed by the abandoned import instead of folding, and the diagnostic for the unmatched brace points at the *last* line of the file rather than at the *opening* line — the gutter therefore draws the issue on the wrong line.

Regression introduced by `c70a5ae` (the remediation of the review findings on PR #135), merged as part of `1d09ab8`.

## Reproduction

1. Check out master `1d09ab8`.
2. Parse the sample below with `HighlightFoldableBlockParser` in scala mode (e.g. through `test/src/folding/parsers/test_executor.dart`'s `parseAndCheck`).
3. Compare with merge-base `25e4c1a` (pre-#135).

```scala
import users.{
  User

class MyClass {
  def method() = {
    body
  }
}
```

```text
merge-base 25e4c1a (pre-#135):
  blocks = [braces(3..7), braces(4..6)]
  invalid = [InvalidFoldableBlock(startLine: 0, type: braces)]

master 1d09ab8 (post-#135, with c70a5ae):
  blocks = [braces(4..6)]
  invalid = [InvalidFoldableBlock(endLine: 7, type: braces)]
```

Two things are wrong: the class block `braces(3..7)` is gone, and the unmatched
brace is reported at the closing line (end 7) instead of the opening line
(start 0).

JavaScript is unaffected in the same way — `import {` carries no qualifier, so
the fix does not absorb it at all, and the JS unclosed case matches merge-base
exactly (`blocks=[braces(3..5)]`, `invalid=[startLine:0]`).

Note: `c70a5ae` adds a test that pins the narrowed Scala behaviour
(`highlight_parser_scala_test.dart` → "An unclosed import brace stops absorbing
after a keyword line", expecting `[braces(2..4)]` + `invalid:[endLine:5]`), so
that test has to move too.

## Suspected Code Paths

- `lib/src/folding/parsers/highlight.dart:onImportTerminatorLine()` — sets
  `_importPairBlockDepth = 0` when a terminator line passes while
  `inImportPairBlock`, without re-registering the still-open absorbed pair as a
  started block. The pair was never `startBlock`ed, so `finalize()` reports a
  leftover *closing* brace instead of the missing opening one.
- `lib/src/folding/parsers/highlight.dart:_startPairOrBlock()` — absorbs any
  pair character while `inImportPairBlock`, so the class's own `{` on the
  keyword line is still absorbed: `submitCurrentLine` (which fires the
  terminator and the depth reset) only runs at the **end** of the line, after
  the line's pair characters have been consumed.

## Root Cause Hypothesis

Confidence: high. The absorption stack is only ever unwound by a matching pair
character; the abandonment path empties the depth counter but drops the record
of what was open. Consequences: (a) the block that opens on the same line as
the terminator (the class) is absorbed and never started, so it cannot fold;
(b) the class's closing brace later pairs with the method's opening brace, and
the final closing brace is left dangling, which `finalize()` reports as
`endLine`-only — line 7 instead of line 0.

**Severity**: medium

**Preferred remediation**: make abandonment restore the pre-absorption state.
When the absorption is abandoned with pairs still open, re-register each
still-open absorbed pair as a started block (`startBlock(line, type)`) so
`finalize()` reports it invalid at its **opening** line, and let the pairs that
follow pair normally. The pre-#135 behaviour then falls out for both languages
and the diagnostic points at the import line — the one the editor should put the
caret on.

Assessment: `.specify/bugs/scala-unclosed-import-fold/assessment.md`
