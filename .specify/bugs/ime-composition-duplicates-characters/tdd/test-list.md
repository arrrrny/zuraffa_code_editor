# TDD Test List: IME composition duplicates/drops characters

- **Slug**: ime-composition-duplicates-characters
- **Issue**: 11

| # | Test | Status |
|---|---|---|
| 1 | a composing-only platform update is stored (Windows desync root cause) | pass (was RED) |
| 2 | a composition commit keeps the candidate text | pass (was RED) |
| 3 | the paired-symbol modifier does not fire while composing | pass (was RED) |
| 4 | a transient out-of-range selection during composition does not throw | pass (was RED) |
| 5 | a read-only field ignores composition text changes | pass |
| 6 | Enter and Tab actions are ignored while composing | pass (was RED) |
| 7 | the autocomplete popup ignores arrow keys while composing | pass (was RED) |
| 8 | `buildTextSpan` delegates to the composing-aware default while composing | pass (was RED) |
| 9 | the Enter shortcut does not reach the editor while composing | pass |
| 10 | `Code.getEditResult` clamps out-of-range old/new selections | pass (was RED) |
