# Spec: Guarded lifecycle continuations (bug mounted-disposed-checks)

Source assessment: ./assessment.md (issue #4, synced from upstream #299)

## Problem

Two async continuations in the package touch dispose-sensitive objects without
checking whether the owning object is still alive:

1. `lib/src/gutter/error.dart` — `Future.delayed(50ms, ...)` calls `setState`
   on the error-icon popup's `State` unconditionally. Disposing the widget in
   that 50ms window throws `setState() called after dispose()`.
2. `lib/src/search/controller.dart` — `_onEnterKeyPressed()` awaits
   `Future.delayed(Duration.zero)` and then calls
   `patternFocusNode.requestFocus()`. Disposing the search controller (which
   disposes `patternFocusNode`) in that window throws.

The headline sites from upstream #299 (`code_field.dart` post-frame callbacks,
`CodeController.analyzeCode`) are already guarded in this fork; the audit in the
assessment found these two remaining sites.

## Acceptance criteria

- AC1: Disposing the gutter error popup widget between the mouse-exit event and
  the 50ms delayed callback does not throw, and the popup state is not touched
  afterwards.
- AC2: Pressing Enter with search shown and disposing the CodeController within
  the same event-loop turn does not throw.
- AC3: Normal (non-disposed) behavior is unchanged: the popup still closes after
  the mouse leaves it, and Enter still moves focus to the search pattern field.
- AC4: All 295 pre-existing tests stay green.

## Failing-test scenarios (red)

1. Widget test: pump the gutter error icon, send a mouse-exit pointer event,
   unmount the widget, pump 60ms → currently throws
  `setState() called after dispose()`.
2. Widget test: pump a CodeField, show search, dispatch the Enter key to the
   pattern field, dispose the controller immediately, pump → currently throws
   (focus request on a disposed node).

## Out of scope

- The already-guarded sites (verified, not re-fixed).
- `popup_controller.dart`'s post-frame `jumpTo` — already safe via `isAttached`.
