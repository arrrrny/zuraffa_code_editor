# Bug Spec: IME composition duplicates/drops characters

- **Slug**: ime-composition-duplicates-characters
- **Issue**: 11
- **Severity**: high
- **Platform**: Windows desktop (duplication), web (dropped characters)

## Symptom

With a Chinese/Japanese/Korean IME active, the editor inserts two characters
for one typed character (Windows) or drops characters from a committed
composition (web). Reproduced at controller level: a committed composition
`'} 你'` became `'} n'` — the candidate was deleted together with the pinyin.

## Scope of the fix on this fork

1. `lib/src/code_field/code_controller.dart`
   - New `hasActiveComposition` getter (`composing.isValid &&
     !composing.isCollapsed`).
   - `set value`: composing-only updates are no longer dropped; while a
     composition is active in the old or new value the platform value is
     stored verbatim after `_updateCodeIfChanged` sync, with read-only text
     changes still ignored.
   - `onKey`, `onEnterKeyAction`, `onTabKeyAction` return early while
     composing.
   - `buildTextSpan` delegates to the default implementation while composing
     so the composing range renders underlined.
2. `lib/src/code_field/code_field.dart` — Enter/Tab/Escape shortcuts are only
   registered when no composition is active.
3. `lib/src/code/code.dart` — `getEditResult` clamps old/new selections into
   `[0, text.length]` before diffing (IME transient out-of-range selections).

## Fix

While composing, the platform owns the text and the selection; the editor
transforms are diff-based and cannot describe a composition replace, so they
must not run. Latin (non-composing) input keeps the exact previous code path —
no behavior change for the diff-based modifiers, history and hidden-range
recovery.

## Out of scope

- Undo/redo across a composition: composition steps intentionally do not push
  history records (upstream behavior).
- IME candidate-window positioning and any engine-side duplication.
- Other composition-adjacent bugs (CJK IME duplicates, fork #41) are tracked
  separately but share this family.
