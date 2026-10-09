# Bug Issue: Material 3 causes progressive misalignment between code and line numbers

- **Slug**: material3-progressive-misalignment
- **Fetched**: 2026-10-09
- **Issue**: 28
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/28
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
**Note: This issue is about misalignment that progresses with each line. For equally misaligned lines with Material 2, see #261**

Steps to reproduce:
1. Take the 02.code_field example as of 0f18b2b1dab6cf7db3aeeb152fc02d287e662ea7
2. Add the following property to `MaterialApp`:

```dart
      theme: ThemeData(
        useMaterial3: true,
      )
```

- Without that, numbers are either aligned or equally misaligned, as described in https://github.com/akvelon/flutter-code-editor/issues/261
- With that:
(web and iOS screenshots attached on the upstream issue)
```

Synced from upstream `akvelon/flutter-code-editor#262 — "Material 3 causes progressing misalignment in code and line numbers"`.

## Why it matters

Misalignment that grows line by line means the gutter and the text use
different line metrics. Our fork already floors Material 3 (Flutter >= 3.10
defaults `useMaterial3: true`), so this is the default theme on the fork, not
an opt-in. Related forks issues: #6 (gutter alignment) and #19 (line numbers
escape the widget) — likely the same subsystem.

## Acceptance criteria

- [ ] Root cause identified (different `TextStyle`/`strutStyle` metrics between gutter and code, or a per-line height drift)
- [ ] Gutter and code stay aligned for a long document under a Material 3 theme
- [ ] A regression test pins the metric source

## Comments

None.
