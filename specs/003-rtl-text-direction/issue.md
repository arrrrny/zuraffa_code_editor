# Feature Issue: RTL / Arabic text direction support

- **Slug**: rtl-text-direction
- **Fetched**: 2026-10-09
- **Issue**: 14
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/14
- **State**: open
- **Author**: arrrrny
- **Labels**: spec

## Body

Upstream body verbatim (excerpt):

```
Currently, the `flutter_code_editor` does not properly handle Right-to-Left
(RTL) languages, specifically Arabic.
...
### Expected Behavior
* The editor should detect or allow setting the `textDirection` to `TextDirection.rtl`.
* Proper cursor placement and movement logic for RTL text.
* Support for Arabic characters without overlapping or rendering issues in the code lines.
```

The reporter offers to contribute. Upstream commenters point at the independent
fork `heckmon/code_forge`, which carries a dedicated RTL workaround.

Synced from upstream `akvelon/flutter-code-editor#317 — "Support for Arabic
Language and RTL Directionality"`.

## Acceptance criteria

- [ ] `CodeField`/`CodeTheme` honor a `textDirection` (or `Directionality` from context)
- [ ] Gutter (line numbers) stays on the correct side and aligned with RTL text
- [ ] A widget test renders an Arabic snippet with RTL and pins the gutter side
