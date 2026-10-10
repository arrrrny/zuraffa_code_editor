# Bug Issue: `wrap: true` does not wrap long lines

- **Slug**: wrap-true-does-not-work
- **Fetched**: 2026-10-09
- **Issue**: 9
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/9
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
I try to use the property "Wrap = true" for long text but it does not work. Please help.

CodeField(
  controller: codeController, // Your CodeController for managing text input
  textStyle: TextStyle(fontSize: 14),
  wrap: true, // Enable text wrapping
)
```

Synced from upstream `akvelon/flutter-code-editor#285 — "Wrap = true does not work"`.
Related upstream discussion: akvelon/flutter-code-editor#221 ("Please support word
wrap", acknowledged hard: line metrics are unavailable through `TextField`) and
#191 (duplicate).

## Why it matters

`wrap: true` is the documented way to enable soft wrapping and it silently does
nothing, which reads as a broken public API.

## Acceptance criteria

- [x] Root cause identified (is the flag forwarded to the underlying `TextField`/`EditableText`?)
- [x] Either wrapping works with `wrap: true`, or the parameter is documented/honoured consistently
- [x] A regression test pins the resulting behavior

## Comments

None.
