# Bug Assessment: Unclosed Scala import brace swallows the class block below it

- **Slug**: scala-unclosed-import-fold
- **Created**: 2026-10-12
- **Source**: pasted text (own finding — before/after probe across revisions, during the pool review remediation of PR #135)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Regression introduced by `c70a5ae` (the pool's own remediation of the review
findings on PR #135), merged to master as part of `1d09ab8`. Probe output, same
script on both revisions (scala highlight mode, folding parser):

```text
code:
  import users.{
    User

  class MyClass {
    def method() = {
      body
    }
  }

merge-base 25e4c1a (pre-#135):
  blocks = [braces(3..7), braces(4..6)]
  invalid = [InvalidFoldableBlock(startLine: 0, type: braces)]

master 1d09ab8 (post-#135, with c70a5ae):
  blocks = [braces(4..6)]
  invalid = [InvalidFoldableBlock(endLine: 7, type: braces)]
```

Two things are wrong on master: the class block `braces(3..7)` is gone, and the
unmatched brace is reported at the *closing* line (end 7) instead of the
*opening* line (start 0) — the gutter therefore draws the issue on the wrong
line.

JavaScript is unaffected in the same way: `import {` carries no qualifier, so
the pool's fix does not absorb it at all, and the JS unclosed case matches
merge-base exactly (`blocks=[braces(3..5)]`, `invalid=[startLine:0]`).

Note: `c70a5ae` adds a test that pins the narrowed Scala behavior
(`highlight_parser_scala_test.dart` → "An unclosed import brace stops absorbing
after a keyword line", expecting `[braces(2..4)]` + `invalid:[endLine:5]`), so
that test has to move too.

## Symptom

With an unclosed Scala selective-import brace (`import users.{` with no closing
`}`), the first real block after the import is swallowed by the abandoned
import instead of folding, and the diagnostic for the unmatched brace points at
the last line of the file rather than at the import line that left it open.

## Reproduction

1. Check out master `1d09ab8`.
2. Parse the sample above with `HighlightFoldableBlockParser` in scala mode
   (e.g. through `test/src/folding/parsers/test_executor.dart`'s
   `parseAndCheck`).
3. Observe `blocks == [braces(4..6)]` and
   `invalid == [InvalidFoldableBlock(endLine: 7, braces)]`; compare against
   merge-base `25e4c1a`, which yields `braces(3..7)` and `startLine: 0`.

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

## Proposed Remediation

**Preferred**: make abandonment restore the pre-absorption state. When the
absorption is abandoned with pairs still open, re-register each still-open
absorbed pair as a started block (`startBlock(line, type)`) so `finalize()`
reports it invalid at its **opening** line, and let the pairs that follow be
paired normally. The pre-#135 behaviour (blocks and diagnostic both) then
falls out for both languages, and the abandoned-import diagnostic points at the
import line — the same one the editor should put the caret on.

This is the shape of the remediation that was prepared for the #135 review and
superseded by `c70a5ae`; it is still available as a git stash
("superseded remediation: reorder+stack+abandon") in the `zuraffa_117`
worktree, but it should be re-derived on top of `c70a5ae` rather than replayed
wholesale — the qualifier gate and the stack can both stay.

**Alternatives**:

- Re-derive with the pool's `_importPairBlockDepth` counter kept, and have
  `onImportTerminatorLine()` remember the line/type of the open pair(s) so the
  abandonment can re-register them. Smaller diff than replacing the counter
  with a stack, but it carries the same "who is open" information the counter
  already lost, so it needs a list anyway — the stack is the honest shape.
- Leave the diagnostic as `endLine` and only restore the class fold: wrong —
  the gutter would still point at the wrong line, which is the part a user
  notices while typing a half-finished import.

**Files likely to change**:

- `lib/src/folding/parsers/highlight.dart`
- `test/src/folding/parsers/highlight_parser_scala_test.dart` (the
  `c70a5ae` test must be re-pinned to the restored behaviour)
- `test/src/folding/parsers/highlight_parser_js_test.dart` (pin the JS
  unclosed case against the same shape, as a regression guard)

**Tests to add or update**:

- Unclosed Scala import + class below: `braces(3..7)` + `braces(4..6)` +
  `invalid:braces@0` — i.e. exactly the pre-#135 behaviour.
- Unclosed Scala import + function below (the pool's own fixture, re-pinned).
- Unclosed JS import: unchanged, `braces(3..5)` + `invalid:braces@0`.
- The closed Scala selective import must keep folding as one imports block
  (the #117 feature's own tests guard this).

## Risks & Considerations

- The fix touches the same parser that #117 just shipped; every language's
  folding suite is the regression guard and must stay green.
- A block re-registered as started but never closed becomes an invalid block —
  that is the point, but it must not invalidate blocks that close correctly
  after an abandoned import.
- `tool/coverage_gate.py` pins exempted lines by number; any insertion in
  `highlight.dart` shifts them and the 100% gate must be re-checked.

## Open Questions

- [NEEDS CLARIFICATION: none — the pre-regression behaviour is recorded in the
  #135 review probe, so "expected" is not a judgement call.]
