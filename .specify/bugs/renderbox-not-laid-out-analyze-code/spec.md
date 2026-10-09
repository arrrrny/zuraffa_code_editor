# Bug Spec: RenderBox was not laid out when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Issue**: 32
- **Severity**: low
- **Platform**: all

## Symptom

`RenderBox was not laid out: … Failed assertion: 'hasSize'` thrown
`while dispatching notifications for CodeController`, originating in
`_CodeFieldState._onTextChanged` → `box.localToGlobal(Offset.zero)`.

## Scope of the fix on this fork

`lib/src/code_field/code_field.dart` only.

1. Add a private seam:
   ```dart
   bool get _isEditorBoxLaidOut {
     final box = _editorKey.currentContext?.findRenderObject() as RenderBox?;
     return box != null && box.hasSize;
   }
   ```
2. `_onTextChanged` — read `_editorOffset` and call `rebuild()` only when
   `_isEditorBoxLaidOut`.
3. `_updatePopupOffset` — return early when `!_isEditorBoxLaidOut`.

## Fix

`hasSize` on the editor's own render box is the direct statement of "layout has
produced a size for this box", which is exactly what `localToGlobal` requires.
It is also the narrowest possible check: it is false only in the window between
the editor box being mounted and its first layout, i.e. only when the
notification would otherwise crash.

Behavior change: none. When the box is laid out the code runs exactly as
before. When it is not, the offset read is skipped and the `setState` is
deferred to the next frame — the frame after the layout that makes the offset
meaningful.

## Out of scope

- `GutterWidget`'s `AnimatedBuilder` reacting to a mid-frame notification with
  `setState` (`Build scheduled during frame`) — same family, separate report.
- The upstream-reported `ScrollController not attached` assertion — already
  fixed on this fork via `scrollOffsetOrZero` (issue #10).
