# Bug Issue: Autocomplete popup transparency cannot be turned off

- **Slug**: autocomplete-popup-transparency
- **Fetched**: 2026-10-09
- **Issue**: 34
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/34
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
Is it possible to turn off transparency for autocomplete popup?

![image](https://github.com/akvelon/flutter-code-editor/assets/33786293/edeb84cc-8018-4384-be4d-6005549d1df5)
```

Synced from upstream `akvelon/flutter-code-editor#273 — "[question] Autocomplete transparency"`.

## Why it matters

The popup's background is translucent with no knob to make it opaque, so
suggestions are hard to read over code. This is a missing style option, not a
crash.

## Acceptance criteria

- [ ] The popup's background opacity is configurable (or the styling is lifted from the theme)
- [ ] A test pins the default and the configured appearance

## Comments

None.
