# Bug Issue: IME composition duplicates/drops characters (non-Latin input)

- **Slug**: ime-composition-duplicates-characters
- **Fetched**: 2026-10-09
- **Issue**: 11
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/11
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
### win11
1. 输入一个字符进入输入框会出现两个字符

## web
1. 输入两个字符进入输入框只会显示一个字符
```
(Windows desktop: typing one character inserts two. Web: typing two characters
shows one. Reported with a short screen recording.)

Synced from upstream `akvelon/flutter-code-editor#309 — "[bug] 中文输入有问题"`.

## Why it matters

IME/`TextRange.composing` handling is what makes the editor usable for Chinese,
Japanese and Korean users. The controller's text-diff based `CodeModifier`s are
a prime suspect: a composition session mutates the value in ways a `+1 char`
diff does not describe, so modifiers (auto-indent, bracket pairing, service
comment parsing) can re-apply or drop text.

## Acceptance criteria

- [ ] A widget test that drives a composition (`TextEditingValue` with a
      non-negative `composing` range) reproduces the wrong output count
- [ ] Commit/transform points skip modifier application while composing
- [ ] Latin input tests stay green (no regression for the diff-based path)

## Comments

None.
