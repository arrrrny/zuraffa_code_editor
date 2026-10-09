# Bug Issue: Reusing a RegExp causes a JavaScript error on web (autocompleter split)

- **Slug**: regexp-reuse-js-error
- **Fetched**: 2026-10-09
- **Issue**: 24
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/24
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```
## Steps to reproduce:

1. Start the example app.
2. Click to the bottom empty line.
3. Press Enter.
4. Click to `readOnlyMethod` method name.
5. Press Enter.

**Expected:** Nothing happens.
**Acutal:** Cursor is moved to the bottom, an empty line is added there.

Reproducible in:
- Web, Flutter 3.3, with the message in the console (see below).
- Web, Flutter 3.0, no messages in console.

Not reproducible in Linux Desktop.

Found in commit: 72caacd2975e80e0c3e3f477b6d82c7b0ef271ce
```

Synced from upstream `akvelon/flutter-code-editor#61 — "Reusing a RegExp causes a JavaScript error"`. Full report (JS stack trace showing `JSNoSuchMethodError` from `TextInputClient.updateEditingState`, failing `_updateText`, `flutter doctor -v`) preserved on the fork issue.

## Why it matters

On web, reusing a compiled `RegExp` across `String.split` calls trips a dart2js
`lastIndex` bug: the next engine call sees a null match group and throws,
which surfaces as corrupt editing state (cursor jumps, phantom lines).

## Acceptance criteria

- [ ] Audit every `RegExps.*` reuse site in lib/ (`autocompleter.dart`, `text_editing_value.dart`, ...) for the same dart2js hazard
- [ ] Any remaining reuse is wrapped in a fresh `RegExp(pattern)` (or otherwise made safe)
- [ ] A unit test pins the splitting/parsing behavior that regressed upstream

## Comments

None.
