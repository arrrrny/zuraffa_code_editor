# Bug Issue: Auto-scroll does not follow the caret while typing

- **Slug**: auto-scroll-caret
- **Fetched**: 2026-10-09
- **Issue**: 42
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/42
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
when we enters a code line by line on the same screen auto scroll not working it goes lines down for scroll we need scroll manually.
```

Synced from upstream `akvelon/flutter-code-editor#316 — "vertical automatic scroll bar on flutter code editor"`.

## Why it matters

Typing past the bottom edge should scroll the view to the caret; requiring a
manual scroll makes long edits painful.

## Acceptance criteria

- [ ] Typing at the bottom edge keeps the caret visible
- [ ] A regression test pins caret-following (widget test with a long document)

## Comments

None.
