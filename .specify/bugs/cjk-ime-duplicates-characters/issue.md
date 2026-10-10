# Bug Issue: Chinese (CJK) IME input duplicates or drops characters

- **Slug**: cjk-ime-duplicates-characters
- **Fetched**: 2026-10-09
- **Issue**: 41
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/41
- **State**: closed (2026-10-10 — fixed by PR #44; the IME-composition guards in `CodeController.value`/`onKey`/`onEnterKeyAction` plus `_shortcutsIgnoredWhileComposing` stop the editor transforms that duplicated or dropped composing characters)
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
(screenshot on the upstream issue)

### win11
1. 输入一个字符进入输入框会出现两个字符

## web
1. 输入两个字符进入输入框只会显示一个字符
```

Synced from upstream `akvelon/flutter-code-editor#309 — "[bug] 中文输入有问题"`.

## Why it matters

CJK input is unusable: one composed character arrives as two, and on web two
arrive as one. Same family as fork issue #11 (IME composition duplicates /
drops characters, upstream #126) — this report is the CJK-specific instance,
worth its own tracking because the composition path differs per locale.

## Acceptance criteria

- [ ] Composing a CJK character yields exactly one character in the field (Windows)
- [ ] Web composition does not drop characters
- [ ] A regression test pins the composing-range handling

## Comments

None.
