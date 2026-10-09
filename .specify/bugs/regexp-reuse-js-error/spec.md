# Bug Spec: Reusing a RegExp causes a JavaScript error on web

- **Slug**: regexp-reuse-js-error
- **Issue**: 24
- **Severity**: low
- **Platform**: web (dart2js) only

## Symptom

On web, engine calls against a reused `RegExp` instance misbehave after a
prior call leaves `lastIndex` state behind. Upstream saw `JSNoSuchMethodError`
thrown from `TextInputClient.updateEditingState` → `autocompleter.dart:_updateText`
→ `String.split(RegExp)`, surfacing as cursor jumps and phantom lines.

## Scope of the fix on this fork

1. `lib/src/autocomplete/autocompleter.dart` — the originally reported call
   site already uses the fresh-instance form (`RegExp(RegExps.wordSplit.pattern)`);
   no change needed.
2. `lib/src/code_field/text_editing_value.dart` — `_getWordAtCursorStartEnd()`
   still passes the shared `RegExps.wordSplit` straight to
   `lastIndexOf` / `indexOf`. This is the remaining instance of the hazard and
   runs on every cursor move.

## Fix

Route both engine calls through a documented seam:

```dart
@visibleForTesting
RegExp wordSplitPatternForScan() => RegExp(RegExps.wordSplit.pattern);
```

Behavior on the VM is unchanged (the VM caches the compiled pattern and a
freshly constructed instance behaves identically — the hazard only exists on
dart2js, which has no such cache and can carry `lastIndex` state on a reused
instance).

## Out of scope

- Auditing third-party packages for the same hazard.
- The `RegExp` cache semantics themselves.
