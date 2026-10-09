# Bug Issue: RenderBox was not laid out assertion when analyzeCode notifies during layout

- **Slug**: renderbox-not-laid-out-analyze-code
- **Fetched**: 2026-10-09
- **Issue**: 32
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/32
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim (trimmed to the error sections; full report on the fork issue):

```
When I run my project, using the CodeField option I get an error in the console,
but the application continues working normally, should I be worried?
I am using Flutter version 3.22.2, Dart version 3.4.3.

======== Exception caught by foundation library ============
The following assertion was thrown while dispatching notifications for CodeController:
RenderBox was not laid out: RenderTransform#73e3d NEEDS-LAYOUT NEEDS-PAINT ...
Failed assertion: line 2165 pos 12: 'hasSize'
#7      _CodeFieldState._onTextChanged (code_field.dart:330:28)
#8      ChangeNotifier.notifyListeners (change_notifier.dart:433:24)
#9      CodeController.analyzeCode (code_controller.dart:224:5)

======== Exception caught by foundation library ============
The following assertion was thrown while dispatching notifications for CodeController:
ScrollController not attached to any scroll views.
#4      _CodeFieldState._getPopupLeftOffset (code_field.dart:524:34)
#5      _CodeFieldState._updatePopupOffset (code_field.dart:487:24)
#9      CodeController.analyzeCode (code_controller.dart:224:5)
```

Synced from upstream `akvelon/flutter-code-editor#275 — "CodeField error"`.

## Why it matters

Two assertions fire when `analyzeCode()`'s notification lands mid-layout. One
of them — `ScrollController not attached` in `_getPopupLeftOffset` — is the bug
already fixed on this fork (issue #10 / scroll-controller-not-attached). The
other — `RenderBox was not laid out` via `_onTextChanged` → `localToGlobal` — is
still open here and produces a red console on a plain first layout.

## Acceptance criteria

- [ ] Reproduce (or verify current code path): `_onTextChanged` must not call `localToGlobal` on a box that has not been laid out
- [ ] No assertion in the console for the upstream repro (CodeController + CodeField inside CodeTheme)
- [ ] Regression test pins the behavior

## Comments

None.
