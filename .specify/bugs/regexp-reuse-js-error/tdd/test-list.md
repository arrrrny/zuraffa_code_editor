# TDD Test List: Reusing a RegExp causes a JavaScript error on web

- **Slug**: regexp-reuse-js-error
- **Issue**: 24

| # | Test | Status |
|---|---|---|
| 1 | seam returns the `RegExps.wordSplit` pattern | pass |
| 2 | repeated `wordAtCursor` / `wordToCursor` / `wordAtCursorStart` on one value are deterministic | pass |
| 3 | word resolution at offsets inside, between, and past words | pass |
