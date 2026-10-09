# Bug Assessment: RenderBox was not laid out when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Issue**: 32 (upstream akvelon/flutter-code-editor#275)
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/32
- **Assessed**: 2026-10-09
- **Verdict**: valid — the code path is unguarded and reproduces; the plain
  first-layout repro from the report does *not* fail on current master

## Reproduction summary

Upstream report (Flutter 3.22.2): with nothing but a `CodeController` +
`CodeField` in the tree, the console shows assertions thrown
`while dispatching notifications for CodeController`, and the app keeps
running. Two assertions were reported:

- `RenderBox was not laid out: RenderTransform#… NEEDS-LAYOUT NEEDS-PAINT …
  Failed assertion: 'hasSize'` at `code_field.dart:330` →
  `_CodeFieldState._onTextChanged` → `ChangeNotifier.notifyListeners` →
  `CodeController.analyzeCode` (`code_controller.dart:224`).
- `ScrollController not attached to any scroll views` at `code_field.dart:524`
  → `_CodeFieldState._getPopupLeftOffset` → `_updatePopupOffset`.

The second one is already fixed on this fork (issue #10,
`scrollOffsetOrZero`). The first is open here.

## What actually reproduces on current master

Verified directly, on `origin/master` (`34f8cb8`), with the current code:

- **Plain first layout does not fail.** `createApp(controller, FocusNode())`
  from `test/src/common/create_app.dart`, `pumpWidget`, `pump(100ms)`,
  `expect(takeException(), isNull)` — passes on master. `analyzeCode()` is
  `unawaited` from the controller constructor and from the `value` setter, so
  by the time its notification lands the editor box is laid out. The reported
  "red console on a plain first layout" is no longer the observable symptom.
- **The code path is still unguarded and still crashes when the notification
  lands mid-frame.** A sibling laid out before the `CodeField` in a `Column`
  that calls `controller.notifyListeners()` from `performLayout()` puts the
  notification exactly where upstream's stack trace is: the editor render box
  is mounted but `flushLayout` is still running, so the box has no size. On
  master that repro throws
  `RenderBox was not laid out: RenderFractionalTranslation#… NEEDS-LAYOUT
  NEEDS-PAINT … Failed assertion: 'hasSize'` from `_onTextChanged`.

## Root cause

`_CodeFieldState._onTextChanged` and `_updatePopupOffset` are listeners on
the `CodeController`. Both assume the editor render box is laid out:

- `_onTextChanged` reads `box.localToGlobal(Offset.zero)`.
- `_updatePopupOffset` calls `setState` and recomputes the popup offsets.

The only guard is `_editorKey.currentContext != null`, which says nothing about
layout state. A `CodeController` notification that lands between the editor
box's mount and its first layout (`hasSize == false`) reaches
`localToGlobal` and asserts. The offset read is also meaningless in that
window, and the `setState` it triggers would itself throw
`setState() or markNeedsBuild() called during build`.

## Proposed fix

Add one seam, `_isEditorBoxLaidOut` (`box != null && box.hasSize`), and:

- `_onTextChanged` reads the offset and calls `rebuild()` only when the box is
  laid out.
- `_updatePopupOffset` returns early when it is not.

`SchedulerBinding.instance.schedulerPhase` was tried first as the discriminator
and rejected: during the initial frame layout the phase is `idle`, not
`transientCallbacks`, so it does not identify the window. `hasSize` on the
editor's own render box is the direct signal.

## Not in scope (recorded, deliberately)

`GutterWidget` (`lib/src/gutter/gutter.dart:33`) wraps its column in
`AnimatedBuilder(animation: codeController)`. `_AnimatedState._handleChange`
calls `setState`, which throws `Build scheduled during frame` for *any*
controller notification that lands mid-frame — on master too, independent of
this fix. That is a second, pre-existing defect in the same
"notification lands mid-frame" family. The regression test therefore pumps the
field with `GutterStyle.none` so the gutter's `AnimatedBuilder` stays out of the
tree, and the mid-frame `setState` in the gutter is left as its own report.

## Severity / effort

- Severity: low (console noise; the app keeps running, and on modern Flutter the
  reported plain first layout is already clean).
- Effort: small — one getter, two call sites, no API change, no behavior change
  once the box is laid out.
