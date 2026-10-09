# Bug Test Report: Reusing a RegExp causes a JavaScript error on web

- **Slug**: regexp-reuse-js-error
- **Issue**: 24
- **Result**: pass (with a platform caveat)

## TDD cycle

1. RED — `test/src/code_field/word_boundary_pattern_test.dart` written first;
   failed to compile (`wordSplitPatternForScan` undefined).
2. GREEN — seam added, both engine calls routed through it; all tests pass.
3. Mutation — replacing the constructed pattern with a wrong one fails the
   contract test.

## Coverage of the fix

- Contract: pattern equality with `RegExps.wordSplit.pattern`.
- Behavior: repeated word lookups on one value are deterministic; word
  resolution at offsets inside, between, and past words is unchanged.

## Caveat (honest)

The defect itself is dart2js-only and the VM caches the compiled pattern (a
fresh instance behaves identically), so the "revert to the shared instance"
mutation cannot fail any VM test. Same
honesty standard as the mounted/disposed bug's verification: record the gap
rather than claim full mutation coverage.
