# Bug Assessment: Missing mounted/disposed checks

- **Slug**: mounted-disposed-checks
- **Created**: 2026-10-09
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/4 (synced from https://github.com/akvelon/flutter-code-editor/issues/299)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Upstream report: the library uses `WidgetsBinding.instance.addPostFrameCallback`
and accesses `context` in the callback without checking mounted state, and
`CodeController.rebuild()` has an async gap before accessing the context without
a disposed check. Upstream PR #298 claims to fix both.

## Symptom

`setState() called after dispose()` / `Looking up a deactivated widget's
ancestor is unsafe` / focus or notify calls on disposed objects when the widget
or controller is disposed between scheduling a callback and its execution.

## Reproduction

1. Show a CodeField; trigger a gutter error popup and move the mouse off the
   error icon, then dispose the widget within 50ms → delayed `setState` throws.
2. Open search in a CodeField, press Enter, then dispose the CodeController
   within the same event-loop turn → `patternFocusNode.requestFocus()` runs on a
   disposed FocusNode and throws.

## Suspected Code Paths

- `lib/src/code_field/code_field.dart:268-275` — post-frame callback reading
  `_codeFieldKey.currentContext!.size` — **already guarded** (`if (!mounted) return;`).
- `lib/src/code_field/code_field.dart:322-334` — post-frame callback inside
  `rebuild()` — **already guarded**.
- `lib/src/code_field/code_controller.dart:228-245` — `analyzeCode()` async gap —
  **already guarded** (`if (_disposed) return;` at line 238).
- `lib/src/gutter/error.dart:49-59` — `Future.delayed(50ms, ...)` calls
  `setState` with **no mounted guard** → genuine remaining defect.
- `lib/src/search/controller.dart:139-144` — `_onEnterKeyPressed()` awaits
  `Future.delayed(Duration.zero)` then calls `patternFocusNode.requestFocus()`
  with **no disposed guard** → genuine remaining defect when the controller is
  disposed in the gap.
- `lib/src/wip/autocomplete/popup_controller.dart:34-38` — post-frame
  `itemScrollController.jumpTo` — already safe: guarded by
  `itemScrollController.isAttached`.

## Root Cause Hypothesis

The two headline sites from upstream #299 were fixed in this fork's repackage
work, but the audit was never completed: two async continuations that touch
dispose-sensitive objects (`setState` on an unmounted State, `requestFocus` on a
disposed FocusNode) remain unguarded. Confidence: high — code read confirms the
unguarded continuations.

## Proposed Remediation

**Preferred**: guard the two remaining continuations.

1. `lib/src/gutter/error.dart` — in the delayed callback, return early when
   `!mounted` before `setState`.
2. `lib/src/search/controller.dart` — add a `bool _disposed = false` flag set in
   `dispose()`; after the `await`, skip `patternFocusNode.requestFocus()` when
   disposed.

**Alternatives**:
- Cancel the delayed future / timers on dispose (cancel-on-dispose). Cleaner in
  theory but requires holding a Future/Timer handle per site; the mounted /
  disposed guard is the minimal, idiomatic Flutter fix and matches how the rest
  of this package already guards these sites.

**Files likely to change**:
- `lib/src/gutter/error.dart`
- `lib/src/search/controller.dart`
- `test/src/gutter/error_popup_dispose_test.dart` (new)
- `test/src/search/search_enter_dispose_test.dart` (new)

**Tests to add or update**:
- Gutter error popup: trigger mouse-exit, unmount the widget, pump past the 50ms
  delay — must not throw (previously: `setState() called after dispose()`).
- Search: with search shown, dispatch Enter, dispose the controller, pump — must
  not throw (previously: focus request on disposed node).

## Risks & Considerations

- Behavior-preserving guards only; no public API change.
- The popup-controller site is safe as-is (isAttached guard); do not touch it
  beyond the audit note.

## Open Questions

- None.
