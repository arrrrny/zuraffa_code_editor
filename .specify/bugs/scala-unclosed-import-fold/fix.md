# Bug Fix: Unclosed Scala import brace swallows the class block below it

- **Slug**: scala-unclosed-import-fold
- **Fixed**: 2026-10-12
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/verification.md

## Summary

`c70a5ae` (merged with #135) abandoned an unclosed absorbed import by emptying
the depth counter, which dropped the record of which pair was still open. The
block that opened on the terminator line was swallowed and the leftover closing
brace was reported as unmatched at the last line instead of the import line.
`highlight.dart` now keeps a stack of open absorbed pairs and re-registers each
one as a started block on abandonment, restoring the pre-#135 behaviour for
both the folds and the gutter diagnostic.

## Changes

| File | Change | Notes |
| --- | --- | --- |
| `lib/src/folding/parsers/highlight.dart` | `_importPairBlockDepth` counter → `_absorbedOpens` stack of `_AbsorbedPair(line, type)` | keeps `c70a5ae`'s `_foundImportQualifier` gate untouched |
| `lib/src/folding/parsers/highlight.dart` | `onImportTerminatorLine` re-registers every still-open absorbed pair via `startBlock(line, type)`, then clears | the gutter diagnostic lands on the import line |
| `lib/src/folding/parsers/highlight.dart` | `enterImportPairBlock(line, type)` takes the opening position | needed for the re-registration |
| `test/src/folding/parsers/highlight_parser_scala_test.dart` | new test "An unclosed import brace keeps the block below it folding." (B1/B2); `c70a5ae`'s keyword-line test re-pinned (B3) | both were RED before the fix |
| `tool/coverage_gate.py` | `highlight.dart` exemption 120 → 123 | three lines added above the exempted line |

## Diff Highlights

```dart
@override
void onImportTerminatorLine() {
  if (!inImportPairBlock) {
    return;
  }

  // A keyword line inside the import's braces means the statement was
  // abandoned — the file is malformed from here on. Stop absorbing pair
  // characters so the rest of the file folds normally, and re-register
  // every still-open absorbed pair as a started block: finalize() then
  // reports it invalid at its opening line, so the gutter points at the
  // import that left it open exactly as it does without absorption.
  for (final open in _absorbedOpens) {
    startBlock(open.line, open.type);
  }

  _absorbedOpens.clear();
}
```

## Tests Added or Updated

- `highlight_parser_scala_test.dart` → "An unclosed import brace keeps the
  block below it folding." — pins `[braces(3..7), braces(4..6)]` +
  `invalid:[startLine:0]`, i.e. exactly merge-base `25e4c1a`.
- `highlight_parser_scala_test.dart` → "An unclosed import brace stops
  absorbing after a keyword line." — re-pinned from `[braces(2..4)]` +
  `invalid:[endLine:5]` to the restored `[braces(1..5), braces(2..4)]` +
  `invalid:[startLine:0]`.

## Local Verification

- Commands run: `flutter test --concurrency=2 test/src/folding/` → 97 green;
  `flutter test --coverage --concurrency=2` (full suite) → 831 green;
  `dart format --set-exit-if-changed` → clean; `flutter analyze --fatal-infos`
  → no issues; `python3 tool/coverage_gate.py --min 100` → 100.00% (3469/3469).
- Mutation audit: 8/8 semantic mutants killed, 1 equivalent
  (`tdd/verification.md`).
- Manual checks: the pre-#135 behaviour was taken from the pool review's own
  before/after probe on PR #135, not from judgement — merge-base `25e4c1a`
  yields `[braces(3..7), braces(4..6)]` + `invalid:[startLine:0]` for the same
  sample, and the fixed branch now matches it.

## Deviations from Assessment

None. The assessment proposed exactly this shape (re-register the still-open
pairs as started blocks) and this branch is based on `c70a5ae`, so the
qualifier gate was already in place and was left alone.

## Follow-ups

- The unclosed-import abandonment is driven by `onImportTerminatorLine`, which
  a keyword terminator reaches. A non-keyword terminator (e.g. a multi-line
  string) ends the sequence without consulting the stack; no current test
  reaches it, noted in `tdd/verification.md`.
