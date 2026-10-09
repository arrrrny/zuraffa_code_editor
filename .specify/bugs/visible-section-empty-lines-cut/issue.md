# Bug Issue: Editing a visible section cuts empty lines before and after it

- **Slug**: visible-section-empty-lines-cut
- **Fetched**: 2026-10-09
- **Issue**: 35
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/35
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
(No description was provided on the upstream issue.)
```

Synced from upstream `akvelon/flutter-code-editor#109 — "Cut empty lines before and after a visible section"`.

## Why it matters

When a visible (folded-away-header) section is edited, the empty lines
surrounding it are removed — a silent data-shape change outside the edited
range.

## Acceptance criteria

- [ ] Reproduce: edit inside a visible section and verify the empty lines around it survive
- [ ] Root cause identified in the visible-section editing path
- [ ] Regression test pins the surrounding lines

## Comments

None.
