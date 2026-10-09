# Bug Issue: Cursor moves incorrectly when pasting code with service comments

- **Slug**: paste-service-comments-cursor
- **Fetched**: 2026-10-09
- **Issue**: 43
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/43
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
(No description was provided on the upstream issue.)
```

Synced from upstream `akvelon/flutter-code-editor#88 — "Cursor moves incorrectly when pasting code with service comments"`.

## Why it matters

Pasting a block containing service comments (which become hidden ranges)
leaves the caret in the wrong place — a silent corruption of the next edit's
target.

## Acceptance criteria

- [ ] Reproduce: paste text with a service comment, caret ends at the end of the pasted block
- [ ] Root cause identified in the paste / hidden-range path
- [ ] A regression test pins the caret position after paste

## Comments

None.
