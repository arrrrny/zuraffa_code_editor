# Chore Issue: List web as a supported platform

- **Slug**: list-web-as-supported-platform
- **Fetched**: 2026-10-09
- **Issue**: 23
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/23
- **State**: open
- **Author**: arrrrny
- **Labels**: chore

## Body

Upstream body verbatim:

```
Currently it is not listed:

![image](https://user-images.githubusercontent.com/44893228/230852134-6451ac43-1391-4d78-9a8d-be7ac603bb10.png)

The first thing is to find why it cannot be automatically detected. Write this reason here. Then we will decide if we fix that reason or explicitly list web as a supported platform.
```

Synced from upstream `akvelon/flutter-code-editor#208 — "List web as a supported platform"`.

## Why it matters

Platform badges on pub.dev are the first thing users check. If web is in fact
usable (the package ships `js_workarounds` and the CI runs the web-capable
suite), it should be listed; if not, the reason should be documented so users
stop asking.

## Acceptance criteria

- [ ] Determine why web is not auto-detected as supported (README/`pubspec.yaml` platform list, or a plugin-with-web-support heuristic)
- [ ] Either web is declared supported, or the unsupported status is documented with the reason

## Comments

- KhushalJangid: "The package is not stable on web, I've tried it but it has bugs like it automatically changes the cursor position on click, not registering clicks etc."
