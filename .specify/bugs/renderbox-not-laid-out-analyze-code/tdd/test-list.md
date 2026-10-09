# TDD Test List: RenderBox was not laid out when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Issue**: 32

| # | Test | Status |
|---|---|---|
| 1 | a mid-frame controller notification does not assert (`_onTextChanged` / `_updatePopupOffset` both run with an unlaid-out editor box) | pass |
| 2 | the deferred part of the mid-frame notification still applies on the next frame | pass |
