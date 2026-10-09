# TDD Cycle Log: Reusing a RegExp causes a JavaScript error on web

- **Slug**: regexp-reuse-js-error
- **Issue**: 24

## RED

`test/src/code_field/word_boundary_pattern_test.dart` written before the fix.
First run failed to compile: `wordSplitPatternForScan` undefined — expected.

## GREEN

Added `wordSplitPatternForScan()` in `lib/src/code_field/text_editing_value.dart`
and routed `_getWordAtCursorStartEnd()` through it. All tests pass.

## Mutation checks

- Constructing a wrong pattern fails the contract test.
- The "pass the shared instance" mutation is not observable on the VM (Dart
  caches `RegExp` by pattern); recorded as a verification gap.

## Full suite

328 tests (existing suite unchanged) pass with the fix in place.
