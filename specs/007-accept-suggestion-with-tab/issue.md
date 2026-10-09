# Spec Issue: Accept an autocomplete suggestion with Tab

- **Slug**: accept-suggestion-with-tab
- **Number**: 007
- **Fetched**: 2026-10-09
- **Issue**: 36
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/36
- **State**: open
- **Author**: arrrrny
- **Labels**: spec

## Body

Upstream body verbatim:

```
(No description was provided on the upstream issue.)
```

Synced from upstream `akvelon/flutter-code-editor#188 — "Make adding suggestion by tab key press"`.

## Why it matters

Accepting an autocomplete suggestion with Tab is the default muscle memory in
every mainstream editor. Without it the popup is mouse-only for acceptance.

## Acceptance criteria

- [ ] With the suggestion popup open, Tab inserts the selected suggestion
- [ ] With the popup closed, Tab keeps its current indentation behavior (see spec 006, Tab via shortcuts)
- [ ] Tests pin both branches

## Comments

None.
