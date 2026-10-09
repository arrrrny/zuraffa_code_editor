# Bug Issue: Page up / Page down does not scroll the CodeField

- **Slug**: page-up-down-does-not-scroll
- **Fetched**: 2026-10-09
- **Issue**: 27
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/27
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
(No description was provided on the upstream issue.)
```

Synced from upstream `akvelon/flutter-code-editor#195 — "Page up / Page down doesn't scroll the CodeField"`.

## Why it matters

Page Up/Page Down are core desktop navigation keys. When they do nothing the
editor feels broken on the platform where a code editor matters most.

## Acceptance criteria

- [ ] Reproduce: Page Up / Page Down with a focused CodeField moves the viewport by one page
- [ ] The scroll offset (and caret, if visible) move accordingly
- [ ] A regression test pins the key handling

## Comments

None.
