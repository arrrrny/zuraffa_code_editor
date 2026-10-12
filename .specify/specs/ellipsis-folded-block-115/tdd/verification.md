# TDD verification: ellipsis-folded-block

Feature: `.specify/specs/ellipsis-folded-block-115/` · Fork issue #115 ·
Upstream `akvelon/flutter-code-editor#86`

This is the evidence trail, not a summary of the code. Every claim here is
produced by a command in this worktree, and the numbers are what the commands
printed.

> **STATUS: not yet filled.** The implementation and its tests have not been
> written, so nothing below is a result. Every number, every RED transcript and
> every mutation verdict in this file is a `TODO` placeholder. The rows and
> headings are the ones the #113 verification uses, so that the file can be
> filled in place without restructuring it. Replace each `TODO` with what the
> command actually printed; do not delete a row because a section turns out to be
> empty — record it as empty with the command that showed it.

## RED first

`test/src/code_field/fold_ellipsis_test.dart` and the new entries in
`test/src/code_field/span_builder_test.dart` are written in full before any
implementation change, and run:

```
flutter test --concurrency=2 \
    test/src/code_field/fold_ellipsis_test.dart \
    test/src/code_field/span_builder_test.dart
```

TODO — expected RED, and RED for the right reason: the tree has no `' …'` leaf,
so the assertions fail on `contains(' …')` / a whole-tree mismatch rather than on
a compile error. Paste the actual output here.

```
TODO — paste the RED transcript.
TODO — note which of T005/T006 failed and why.
```

Then T007–T009 are written, and the same command goes GREEN:

```
TODO — paste the GREEN line, e.g. `00:08 +N: All tests passed!`
```

## Test inventory

TODO — fill the counts once the gate has run.

`test/src/code_field/fold_ellipsis_test.dart`, 16 tests:

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
| With no base style the marker falls back to the line style | RB-004 |
| The painted tree of a folded field carries the marker | FR-001 |
| A match after a folded line still lands on its own text | FR-012 |
| no ellipsis while an IME composition is active | RB-005 |
| no ellipsis when no language is set | RB-005 |

`test/src/code_field/span_builder_test.dart`: **no examples added.** That file
asserts whole trees and every one of its examples is a document with nothing
folded, so the marker cannot appear in any of them and each expected tree is
unchanged. Adding an example there would mean writing a whole expected tree out
for a behaviour the new file already pins leaf by leaf; the decision is recorded
here rather than left as a gap. The three regression files from T002 carry that
net instead.

TODO — record any test that started out wrong and was corrected rather than the
implementation bent to fit it, and what the correction taught about the contract.
Two occurred here and are worth the treatment #113 gave its three:

1. **The expected visible text of `foldAt(0)` on the shared-closing-line
   fixture.** The first draft of that test's fixture had `}` alone on the last
   line, which reads as "the closer gets a row of its own". It does not: the
   `_isClosingLine` branch glues it to the opener, so the rendered line is
   `int factorial(int n){}` and the marker follows the glued closer. The
   closer only takes a row of its own when the closing line also opens the next
   foldable block — hence the `}void main(){` fixture, which is the shape the
   repo already pins in `folded_block_keeps_next_block_start_test.dart`. The
   correction taught that "closer on its own row" is a property of what follows
   the closer, not of the fold itself.
2. **The line index a terminating node reports.** The first draft assumed
   `_visibleLineIndex` after `_updateLineIndex` is the line the node ends. It is
   the line the node *starts on* plus its own newline count, so a node ending
   with `'\n'` terminates the line *before* the counter's current value. The
   splice accordingly targets `_visibleLineIndex - 1`, and the final visible
   line — which has no terminating newline at all — is the one case where the
   counter itself is the line. This is also why `_paleIfRequired` reads
   correctly with the pre-increment counter and the splice reads correctly with
   the post-increment one.

## Regression net

The three files from T002, run **unmodified**:

```
flutter test --concurrency=2 \
    test/src/code_field/span_builder_test.dart \
    test/src/folding/folded_closing_line_test.dart \
    test/src/folding/folded_block_keeps_next_block_start_test.dart
TODO — paste the counts. All must pass.
```

Run together with the new file:

```
flutter test --concurrency=2 \
    test/src/code_field/fold_ellipsis_test.dart \
    test/src/code_field/span_builder_test.dart
TODO — paste the counts.
```

Then the full suite:

```
flutter test --concurrency=2
TODO — paste the counts. Note the known host flake (quickstart.md §7) separately,
TODO — with the single-file re-run that shows it is environmental.
```

## Mutation audit

TODO — fill in once run. Seven mutants, each applied to the real source, run
against the new tests, then restored. The script asserts each restored file's
SHA-256 matches its pre-mutation digest, and prints it:

```
=== M-noSplice === TODO
=== M-midLine === TODO
=== M-lineZero === TODO
=== M-keepAfterUnfold === TODO
=== M-tokenStyle === TODO
=== M-keepNulls === TODO
=== M-lastNodeAlways === TODO
all originals restored byte-identical: TODO
summary: TODO
```

| Mutant | Change | What kills it |
|---|---|---|
| `M-noSplice` | remove the `TextSpan(text: ' …', …)` append | every marker-presence test |
| `M-midLine` | append to every node on the kept line instead of the terminating one | the whole-tree `span_builder_test.dart` examples — the marker appears mid-line |
| `M-lineZero` | treat line 0 as the only kept line | every folded example whose kept line is not line 0 |
| `M-keepAfterUnfold` | derive the kept lines once and never recompute | `drops the ellipsis when the block is unfolded` |
| `M-tokenStyle` | always use the terminating node's style | `styles the ellipsis with the base style, not the token style` |
| `M-keepNulls` | do not discard the nulls from `cutLineIndexIfVisible` | `shows one marker per kept line when a nested fold is swallowed` |
| `M-lastNodeAlways` | append to the last span of the walk unconditionally | `puts no ellipsis on the closer's own row…` and the no-trailing-newline example |

TODO — record any mutant that turned out to survive, and which test was added to
kill it. A surviving mutant is a gap in the test list, not a mutant to drop.

## Static gates

```
dart analyze --fatal-infos
TODO — paste the output. Expected: `No issues found!`

dart format --output=none --set-exit-if-changed .
TODO — paste the output. Expected: `Formatted NNN files (0 changed) in N.NNs.`
```

TODO — record any analyzer warning raised during development and how it was
fixed rather than suppressed.

## Coverage gate

CI-identical procedure from `quickstart.md` §4, run against the final committed
tree on `spec/ellipsis-folded-block-115` rebased onto the tip of `master` (the
merge of #116, so the number is the tree the PR actually proposes):

```text
TODO — paste the gate output, e.g.
All tests passed!                                     (NNN)
zuraffa_code_editor line coverage: 100.00% (NNNN/NNNN lines over NNN files)
excluded individual lines (see EXEMPT_LINES): N
Coverage gate: 100.00% >= 100.00% -- OK
```

TODO — record the numerator/denominator and how they differ from master's, and
state plainly whether any exemption was added for this feature. The expected
answer is none: the three branches — kept-line-and-terminating-node,
final-line-without-a-newline, and the null from `cutLineIndexIfVisible` — all
have named tests and real fixtures.

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
