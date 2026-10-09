# Bug Fix Log: Reusing a RegExp causes a JavaScript error on web

- **Slug**: regexp-reuse-js-error
- **Issue**: 24

## Changed

- `lib/src/code_field/text_editing_value.dart`
  - Added `wordSplitPatternForScan()` (`@visibleForTesting`): builds the
    word-boundary pattern from `RegExps.wordSplit.pattern` per call instead of
    handing the shared instance to the engine.
  - `_getWordAtCursorStartEnd()` now uses that seam for both
    `lastIndexOf` and `indexOf`.
- `test/src/code_field/word_boundary_pattern_test.dart` (new)
  - Pins the seam's contract (pattern matches `RegExps.wordSplit.pattern`).
  - Pins determinism of `wordAtCursor` / `wordToCursor` / `wordAtCursorStart`
    across repeated calls on one value.
  - Pins correct word resolution at several cursor offsets.

## Not changed

- `lib/src/autocomplete/autocompleter.dart` — already on the fresh-instance
  form (the upstream fix for the reported crash).

## Verification limits

The hazard is dart2js-specific; the VM caches `RegExp` objects by pattern, so
the shared-instance mutation cannot be observed by a VM test. The VM-side
pins are the seam's contract and behavioral determinism; the web-specific
value rests on matching the form upstream confirmed fixed
(akvelon/flutter-code-editor#61).
