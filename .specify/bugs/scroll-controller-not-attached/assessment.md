# Assessment: `ScrollController not attached` thrown from the popup-offset path

- **Slug**: scroll-controller-not-attached
- **Issue**: 10 (upstream akvelon/flutter-code-editor#275)
- **Date**: 2026-10-09
- **Reporter's environment**: Flutter 3.22.2 / Dart 3.4.3 (upstream), Android
- **Severity**: medium (console-flooding assertion; app keeps running)
- **Verdict**: valid — real robustness defect; not reproducible as a crash on
  Flutter 3.47.5 (see "Reproducibility"), but the unguarded read is proven by
  the reporter's stack.

## Symptom

The reporter's log (upstream #275, standard `02.simple` example wrapped in a
`SingleChildScrollView`):

```
The following assertion was thrown:
ScrollController not attached to any scroll views.
#2      ScrollController.position (scroll_controller.dart:157:12)
#3      ScrollController.offset  (scroll_controller.dart:165:24)
#4      _CodeFieldState._getPopupLeftOffset (code_field.dart:524:34)
#5      _CodeFieldState._updatePopupOffset  (code_field.dart:487:24)
#6      ChangeNotifier.notifyListeners
#7      CodeController.analyzeCode (code_controller.dart:224:5)
```

## Root cause

`_CodeFieldState._getPopupLeftOffset()` (`lib/src/code_field/code_field.dart:557`)
and `_getPopupTopOffset()` (`:567`) read `offset` straight off the two scroll
controllers the widget owns:

```dart
_horizontalCodeScroll!.offset   // horizontal SingleChildScrollView wrapper
_codeScroll!.offset             // the TextField's own scroll view
```

`ScrollController.offset` is `position.pixels`, and `position` asserts
`positions.isNotEmpty`, i.e. `ScrollController not attached to any scroll views`
whenever the controller has no attached position.

The reads are triggered by `CodeController.analyzeCode()`: it finishes on a later
microtask and then calls `notifyListeners()`, which synchronously reaches
`_updatePopupOffset()`. So the offset reads run from an arbitrary later
microtask, at whatever attach state the field's scroll views happen to be in —
not only from a frame where they are attached.

Both controllers are created in `initState` (`:248-258`) and only receive their
positions when the field's subtree is laid out, so any notification that lands
before that (or while the subtree is being replaced) hits the assertion. The
reporter's layout (field inside an outer vertical `SingleChildScrollView`, so
the field itself never scrolls internally) makes the detached state easy to
reach.

## Fix plan

- Read both offsets through a guarded helper that returns `0` when
  `!controller.hasClients`, so a detached controller degrades to "no scroll
  offset" instead of throwing.
- Expose the helper as `@visibleForTesting` so the guard can be pinned by a unit
  test that actually fails without it (mutation-detectable), since the
  widget-level scenario is not reproducible on a current toolchain.

## Reproducibility

Not reproducible as a widget-test crash on Flutter 3.47.5. Two candidate layouts
were tried and both stay green:

- `Offstage(offstage: true, child: CodeField(...))` — `RenderOffstage` still
  lays its child out, so the scroll views attach normally.
- The reporter's `SingleChildScrollView(child: CodeField(...))` — the field lays
  out inside the parent and attaches.

The widget-test binding builds and lays out in the same synchronous frame, so
the "mounted but not laid out" window that the reporter hit cannot be reached
from a test; the assertion only fires when the notification lands in that
window from outside the frame (real app, older Flutter).

## Out of scope

- The `flutter pub outdated` / analyzer-deprecation cleanup (tracked separately).
- Making the popup survive a detached controller beyond not throwing.
