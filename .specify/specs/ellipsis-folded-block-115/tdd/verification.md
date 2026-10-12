# TDD verification: ellipsis-folded-block

Feature: `.specify/specs/ellipsis-folded-block-115/` · Fork issue #115 ·
Upstream `akvelon/flutter-code-editor#86`

This is the evidence trail, not a summary of the code. Every claim here is
produced by a command in this worktree, and the numbers are what the commands
printed. The final gate run is against `230a849`.

## RED first

`test/src/code_field/fold_ellipsis_test.dart` is written in full before any
implementation change, and run against the unmodified tree:

```
flutter test --concurrency=2 test/src/code_field/fold_ellipsis_test.dart
```

The recorded RED output — 10 of the 12 tests failed, and the two that passed
were the two negative ones (`An unfolded document carries no marker`,
`Folding does not touch the editing buffer`), which is the signature of RED for
the right reason: nothing about the feature exists yet, so only the assertions
that demand its *absence* can hold:

```
             Differ at offset 26

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/src/code_field/fold_ellipsis_test.dart 235:7   main.<fn>.<fn>

00:00 +2 -7: A folded block ends its kept line with an ellipsis. A fold swallowed by another fold carries no marker
00:00 +2 -8: A folded block ends its kept line with an ellipsis. A fold swallowed by another fold carries no marker [E]
  Expected: <1>
    Actual: <0>

00:00 +2 -9: A folded block ends its kept line with an ellipsis. The marker carries the base style, not the token style
00:00 +2 -9: A folded block ends its kept line with an ellipsis. The marker carries the base style, not the token style [E]
  Expected: not null
    Actual: <null>

00:01 +2 -10: The editor renders the marker through buildTextSpan. The painted tree of a folded field carries the marker
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════
The following TestFailure was thrown running a test:
Expected: 'final config = ScraperConfig(\n'
            '  clientType: HttpClientType.crawler,\n'
            '  parsers: [  ], …\n'
            ');\n'
            ''
  Actual: 'final config = ScraperConfig(\n'
            '  clientType: HttpClientType.crawler,\n'
            '  parsers: [  ],\n'
            ');\n'
            ''
   Which: is different.
          Expected: ... ers: [  ], …\n);\n
            Actual: ... ers: [  ],\n);\n
                                  ^
           Differ at offset 86
...
00:01 +2 -10: Some tests failed.

Failing tests:
  /Users/arrrrny/Developer/zuraffa_115/test/src/code_field/fold_ellipsis_test.dart: A folded block ends its kept line with an ellipsis. A closer on its own row gets no marker of its own
  /Users/arrrrny/Developer/zuraffa_115/test/src/code_field/fold_ellipsis_test.dart: A folded block ends its kept line with an ellipsis. A fold swallowed by another fold carries no marker
  /Users/arrrrny/Developer/zuraffa_115/test/src/code_field/fold_ellipsis_test.dart: A folded block ends its kept line with an ellipsis. A keystroke after a fold keeps the marker on the kept line
  /Users/arrrrny/Developer/zuraffa_115/test/src/code_field/fold_ellipsis_test.dart: A folded block ends its kept line with an ellipsis. The kept line carries a trailing marker
  ... and 6 more
```

Every failure is a *content* failure — a tree that lacks the ` …` leaf, a
`_markerLeaf` that is null — and never a compile or load error. The
whole-tree assertion above is the clearest: the expected tree carries the
marker, the actual one does not, and they differ by exactly the marker.

The later phases followed the same discipline. The one that mattered most went
RED *after* the splice worked: `A match after a folded line still lands on its
own text` failed with the highlight covering `  two` instead of `two()` — the
two-character shift the marker causes in the search slicing (tasks.md T025).
That RED is what produced the `withFoldEllipsis` switch rather than a
predicted design, and it is the reason the switch exists at all.

## Test inventory

`test/src/code_field/fold_ellipsis_test.dart`, 19 tests:

| Test | Acceptance criterion |
|---|---|
| The kept line carries a trailing marker | FR-001 |
| An unfolded document carries no marker | FR-002 |
| Unfolding removes the marker and nothing else | FR-004 |
| Folding does not touch the editing buffer | FR-003 |
| A keystroke after a fold keeps the marker on the kept line | FR-005 |
| The marker rides after a closer that shares the kept row | FR-006 |
| A closer on its own row gets no marker of its own | FR-007 |
| The last visible line gets a marker with no newline to splice before | FR-008 |
| Two open folds each carry a marker | FR-010 |
| A fold swallowed by another fold carries no marker | FR-009 |
| The marker carries the base style, not the token style | FR-011 |
| A marker after a comment does not come out comment-coloured | FR-011 |
| A marker on a read-only line is not palled | FR-011 |
| With no base style the marker falls back to the line style | RB-004 |
| The painted tree of a folded field carries the marker | FR-001 |
| A match after a folded line still lands on its own text | FR-012 |
| a match above the fold suppresses the final-line marker | FR-012 |
| no ellipsis while an IME composition is active | RB-005 |
| no ellipsis when no language is set | RB-005 |

`test/src/code_field/span_builder_test.dart`: **no examples added.** That file
asserts whole trees and every one of its examples is a document with nothing
folded, so the marker cannot appear in any of them and each expected tree is
unchanged. Adding an example there would mean writing a whole expected tree out
for a behaviour the new file already pins leaf by leaf; the decision is recorded
here rather than left as a gap. The three regression files carry that net
instead.

Two more tests were added *after* the first mutation audit, each closing a gap
that audit proved rather than a defect it found:

- `A marker on a read-only line is not palled` — no fixture had a fold whose
  kept line is read-only, and a read-only line is the only shape in which the
  terminating node's style differs from the base style (`_paleIfRequired`
  palls the text of a read-only line). See the mutation audit for what this
  pins.
- `a match above the fold suppresses the final-line marker` — replaces the
  vacuous search test described in correction 3 below.

### Corrections made to the tests, not the implementation

Three things were wrong in the tests' first drafts. Each is recorded because
the fix taught something about the contract that the design notes did not:

1. **The expected visible text of `foldAt(0)` on the shared-closing-line
   fixture.** The first draft had `}` alone on the last line, which reads as
   "the closer gets a row of its own". It does not: the `_isClosingLine`
   branch glues it to the opener, so the rendered line is
   `int factorial(int n){}` and the marker follows the glued closer. The
   closer only takes a row of its own when the closing line also opens the
   next foldable block — hence the `}void main(){` fixture, which is the shape
   the repo already pins in
   `folded_block_keeps_next_block_start_test.dart`. The correction taught
   that "closer on its own row" is a property of what follows the closer, not
   of the fold itself.

2. **The line index a terminating node reports.** The first draft assumed
   `_visibleLineIndex` after `_updateLineIndex` is the line the node ends. It
   is the line the node *starts on* plus its own newline count, so a node
   ending with `'\n'` terminates the line *before* the counter's current
   value. The splice accordingly targets `_visibleLineIndex - 1`, and the
   final visible line — which has no terminating newline at all — is the one
   case where the counter itself is the line. This is also why
   `_paleIfRequired` reads correctly with the pre-increment counter and the
   splice reads correctly with the post-increment one.

3. **The vacuous final-line search test.** The first draft of `a match also
   suppresses the final-line marker` folded `class A {` to `class A {}` and
   searched `class` — a match on the fold's *kept line*. It passed, and passed
   under the mutant it was written to kill, because
   `SearchNavigationController._expandFoldedBlocksIfNeed` unfolds any block a
   match overlaps: by the time `buildTextSpan` ran there was no fold left, so
   no marker appeared either way. The replacement fixture folds a block whose
   kept line is the *last visible line* and searches the line *above* it,
   which leaves the fold closed — the only way to have a match at all without
   the search revealing the fold. The correction taught that the search panel
   is not a passive observer: navigating to a match mutates the fold state,
   so any search-and-fold test must check the match does not overlap the fold.

## Regression net

The three files from T002, run **unmodified**:

```
flutter test --concurrency=2 \
    test/src/code_field/span_builder_test.dart \
    test/src/folding/folded_closing_line_test.dart \
    test/src/folding/folded_block_keeps_next_block_start_test.dart
00:07 +10: All tests passed!
00:05 +26: All tests passed!
```

26 tests, all pass.

Run together with the new file:

```
flutter test --concurrency=2 \
    test/src/code_field/fold_ellipsis_test.dart
00:01 +19: All tests passed!
```

Then the full suite (see the coverage gate below).

## Mutation audit

The script is committed at `tdd/mutation_audit.py` (run it from the worktree
root: `python3 .specify/specs/ellipsis-folded-block-115/tdd/mutation_audit.py`).
It applies each mutant to the real source, runs
`flutter test --concurrency=2 test/src/code_field/fold_ellipsis_test.dart`,
restores the file, and asserts each restored file's SHA-256 matches its
pre-mutation digest.

```
=== M-noSplice === KILLED
=== M-noFinalSplice === KILLED
=== M-afterNewline === KILLED
=== M-lineZero === KILLED
=== M-foldableNotFolded === KILLED
=== M-tokenStyle === KILLED
=== M-keepNulls === KILLED
=== M-dropKeptLineCheck === KILLED
=== M-noFinalSearchGate === KILLED
=== M-noSearchSwitch === KILLED

all originals restored byte-identical: True
summary: 10/10 killed
```

| Mutant | Change | What kills it |
|---|---|---|
| `M-noSplice` | the terminating-node splice paints `'x'` instead of the marker | every marker-presence test |
| `M-noFinalSplice` | the final-line append paints `'x'` | `The last visible line gets a marker…` |
| `M-afterNewline` | the marker goes *after* the terminating node's own text (the newline), so it lands at the start of the next row | every whole-tree assertion — the marker moves to the wrong row |
| `M-lineZero` | only line 0 can be a kept line | `The marker rides after a closer…`, `Two open folds each carry a marker` |
| `M-foldableNotFolded` | derive the kept lines from `foldableBlocks` instead of `foldedBlocks` | `An unfolded document carries no marker`, `Unfolding removes the marker…` |
| `M-tokenStyle` | the marker always borrows the terminating node's style | `A marker on a read-only line is not palled` |
| `M-keepNulls` | the nulls from `cutLineIndexIfVisible` are not discarded, so a swallowed inner fold resolves to line 0 | `A fold swallowed by another fold carries no marker` |
| `M-dropKeptLineCheck` | the final-line path loses its kept-line check, so the marker closes the tree of a document that folds nothing | `An unfolded document carries no marker` |
| `M-noFinalSearchGate` | the final-line append is not gated by the search switch | `a match above the fold suppresses the final-line marker` |
| `M-noSearchSwitch` | the search suppression is dropped | `A match after a folded line still lands on its own text` |

The first audit of this list was **8/10**: `M-tokenStyle` and
`M-noFinalSearchGate` survived. Both were test gaps, and both needed an
investigation of the tree to close:

- **`M-tokenStyle`** replaces `rootStyle ?? span.style` at the splice with
  `span.style`. It survived because no fixture could tell the two apart: the
  newline that terminates a kept line is always a plain top-level node
  (`className == null`), so its style is the root style even when the line
  ends inside a comment. Dumping the real tree for the comment fixture showed
  exactly that — the `// first comment line` node is followed by a *separate*
  plain `"\n"` node. The one shape where the terminating node's style
  genuinely differs is a **read-only** line, where `_paleIfRequired` palls the
  line's text: with the mutant the marker comes out palled, with the original
  it keeps the base style. The read-only fixture pins that the marker is
  decoration and is never palled.
- **`M-noFinalSearchGate`** removes the search gate from the final-line
  append. Its test was vacuous (correction 3 above): the match it searched
  overlapped the fold, so `SearchNavigationController` unfolded the block
  before `buildTextSpan` ran. The replacement fixture — a fold whose kept
  line is the last visible line, with the match on the line above — leaves
  the fold closed, and the appended marker is visible under the mutant.

The same audit also proved the `_treeEndsWithNewline` guard redundant: a tree
ending with a newline has an empty visible line after it, which is never a
fold's kept line, so the kept-line check alone covers it. The guard and its
field were removed rather than kept for a test to justify.

A surviving mutant is a gap in the test list, not a mutant to drop — and both
of these turned out to be exactly that, not implementation defects.

## Static gates

```
$ dart analyze --fatal-infos lib test
Analyzing lib, test...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 308 files (0 changed) in 0.68s.
```

No analyzer warning was raised during development that needed suppressing;
the only analyzer-driven change was removing the now-redundant
`_treeEndsWithNewline` field once the audit proved it dead.

## Coverage gate

CI-identical procedure from `quickstart.md` §4, run against the final committed
tree on `spec/ellipsis-folded-block-115` rebased onto the tip of `master`
(`b2721ed`, the merge of #141, so the number is the tree the PR actually
proposes):

```text
wrote helper with 128 imports
04:01 +893: All tests passed!
zuraffa_code_editor line coverage: 100.00% (3554/3554 lines over 109 files)
excluded individual lines (see EXEMPT_LINES): 9
Coverage gate: 100.00% >= 100.00% — OK
```

**No exemption was added for this feature.** The nine `EXEMPT_LINES` are the
pre-existing ones; the only one this branch touches is the `span_builder.dart`
entry, and it was *renumbered*, not added — the never-engaged
`_visibleLineIndex` clamp it covers drifted 75 → 143 when #115 first grew the
file and 143 → 129 when the redundant `_treeEndsWithNewline` guard was deleted
(`chore(gate)` commits `2010d43` and `230a849`). The gate's own
`stale line exemption` report caught both drifts.

The numerator/denominator: **893 tests, 3554/3554 lines over 109 files**. The
3554 differ from the pre-deletion tree's 3561 by exactly the seven covered
lines the redundant guard and its tracking occupied. The earlier run on this
branch read 3553/3554 — the one uncovered line was that clamp, left unexempted
by the drift — and became 3554/3554 once the exemption followed it. Every line
this feature adds is covered by a named test rather than by an exemption: the
three branches — kept-line-and-terminating-node, final-line-without-a-newline,
and the null from `cutLineIndexIfVisible` — all have fixtures of their own.

## Scope confirmation

- No configurability was added: no glyph, colour, size, prefix, suffix or
  position parameter, and no field on `CodeController`.
- The gutter is unchanged: the chevron, the three-column `Table`
  (`gutter.dart:106-122`) and the column widths are untouched.
- The folding machinery is untouched: `foldableBlockToHiddenRange`, `cutString`,
  `cutSelection`, `recoverSelection`, `getEditResult` and the line-numbering
  breakpoints.
- No new public type, no new export; the marker constant is private to
  `span_builder.dart`.
- No overlay layer, no `Stack`, no new scroll controller, no new listener.
- `controller.text` is byte-for-byte identical folded and unfolded, asserted
  rather than argued.
