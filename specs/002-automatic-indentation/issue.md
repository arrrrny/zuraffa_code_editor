# Feature Issue: Automatic indentation on Enter

- **Slug**: automatic-indentation
- **Fetched**: 2026-10-09
- **Issue**: 13
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/13
- **State**: open
- **Author**: arrrrny
- **Labels**: spec

## Body

Upstream body verbatim (excerpt):

```
When a user hits _enter_ in the editor they expect that the new line has the
same indentation as the previous line if I'm not mistaken.

That's not the behavior flutter_code_editor has.

Might we be able to add that?
```

Synced from upstream `akvelon/flutter-code-editor#301 — "Add automatic
indentation on new lines"`. Related: #188 (Tab to insert suggestion), #30 (test
the read-only feature via keyboard events).

## Acceptance criteria

- [ ] Pressing Enter copies the indentation of the current line to the new line
- [ ] Behavior is opt-out (a `CodeField`/`CodeController` flag or a modifier that
      can be disabled) — existing apps must not change behavior by default
- [ ] Unit tests on the controller (no cursor jumps, interaction with
      service-comment ranges and foldable blocks)
