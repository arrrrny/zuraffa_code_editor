# Test list: auto-scroll-controller-write-149

| # | Test | Type |
|---|---|---|
| 1 | a programmatic line-by-line write reveals the caret — 40 `controller.text` / `.selection` writes in a 200px field move the `EditableText`'s `Scrollable` offset above 0, and the gutter follows it | widget (red on master: pixels 0.0, max 816.0) |
| 2 | a write that walks the caret back up reveals it upward — after the reveal at the bottom, `controller.selection` at offset 3 brings the offset back near the top | widget |
| 3 | a caret already in view leaves the scroll alone — a second selection write on line 1 does not move the offset | widget |
| 4 | a write while the field is unfocused leaves the scroll alone — no focus, 40 writes, offset stays 0 | widget |
| 5 | a write that names no selection puts the caret at the end — the framework repairs the -1 selection, and that caret is revealed | widget |
| 6 | a field the host made unscrollable is not scrolled — a `ScrollConfiguration` returning `NeverScrollableScrollPhysics` leaves the offset at 0 | widget |
| 7 | a reveal the host unmounts mid-frame is dropped — `pumpWidget` of an empty tree at the frame the reveal was scheduled for throws nothing | widget |
| 8 | a reveal never takes over an offset that is moving — with the field animating, a write that would need a scroll leaves the offset exactly where the animation put it | widget |

No unit-test seam was needed: the reveal is widget-tree behaviour, and every
guard in it is reachable through a real widget test, so none of the defensive
lines needs a fake or a `@visibleForTesting` hook.

## What the regression taught us

The first version of the fix ran the reveal from the controller listener
straight into a post-frame callback. That reddened two existing tests —
`auto_scroll_caret_test.dart` ("vertical scroll follows the caret while
typing") and `wrap_true_test.dart` ("wrap: true soft-wraps the long line into
the viewport") — both on a pending 500 ms analysis timer rather than on a
scroll assertion.

The cause is ordering, and Flutter says so itself. `EditableTextState`
writes a user-driven value through `_formatAndSetValue`, which notifies the
controller listeners, and only *then* calls `_scheduleShowCaretOnScreen`
(`editable_text.dart:3713` then `:3726`), commented "Wherever the value is
changed by the user, schedule a showCaretOnScreen ... Programmatic changes to
`textEditingValue` do not trigger the behavior even if the text field is
focused." So on every keystroke the framework's reveal was registered *after*
this one, ran *second*, and found the offset already at its target — and the
instant `jumpTo` that replaced its 100 ms `animateTo` starved
`pumpAndSettle` of frames, leaving the analysis timer pending.

Two mechanisms, both load-bearing (verified by disabling each):

- the reveal is deferred through a **microtask**, so it registers its
  post-frame callback after the framework's for the same keystroke, and
- it **yields to an offset already being driven**
  (`position.isScrollingNotifier.value`), so it never cancels the framework's
  animation or a drag the user still holds.

Test 8 pins the second, `auto_scroll_caret_test.dart` pins the pair, and both
were re-verified red with either mechanism removed.

## The unreachable guard, and why it needs no exemption

The `!selection.isValid` early return in `_revealCaret` is unreachable while
the field is focused: `EditableText._didChangeTextEditingValue`
(`editable_text.dart:4919`) repairs an invalid selection to the end of the text
whenever `_hasFocus`, and the reveal is focus-gated, so no write arrives at the
callback with an invalid selection.

It is nevertheless **not** in `EXEMPT_LINES`, and adding it there would be
wrong. `flutter test --coverage` reports `DA:610,22` for the `if` and emits no
`DA` line at all for the `return` on 611 — Dart folds a single-statement `if`
body into the condition's region, so the untaken branch contributes nothing to
the denominator. The gate reads that and counts the file 3603/3603, which is
what it reports. An exemption pinned to 611 would instead be reported as a
"stale line exemption", because it matches no line in `lcov.info`.

So the honest entry for this guard is the comment above it in the source, not
an exemption: if the framework ever stops repairing the selection, the gate
will show the `if` line's count drop and the reviewer gets the signal there.
