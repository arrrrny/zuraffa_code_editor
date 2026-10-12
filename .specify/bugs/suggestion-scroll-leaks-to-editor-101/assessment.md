# Assessment: suggestion-scroll-leaks-to-editor-101

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/101
(upstream akvelon/flutter-code-editor#190).

- **Verdict**: not reproducible on the current stack; the described hand-off is
  structurally impossible for a popup mounted in the root overlay. No code
  change; the no-leak property is pinned with regression tests instead.

## Mechanism (why the gesture cannot leave the popup)

The popup is inserted into the root overlay (`code_field.dart:966`,
`Overlay.of(context).insert(...)`), so it is a **sibling** of the editor's
scroll view in the overlay stack, on top of it. Flutter routes every pointer
input through a single hit-test chain:

- `RenderBoxContainerDefaultsMixin.defaultHitTestChildren`
  (`rendering/box.dart:3359`) walks children in reverse paint order and
  **returns at the first hit**. A pointer over the popup therefore produces a
  chain that contains the popup's `Scrollable` and *not* the editor's — the
  editor is a different branch of the stack and never enters the path.
- Wheel/trackpad signals: `PointerSignalResolver`
  (`gestures/pointer_signal_resolver.dart`) resolves each
  `PointerScrollEvent` to the **first registered handler**, which is the
  deepest widget on that chain — the popup's list. The editor's `Scrollable`
  is not on the chain, so it is never a candidate.
- Drags: the gesture arena only admits recognizers from the same hit-test
  chain, and resolves to the first-added (deepest) claimant — again the popup's
  list, which keeps the pointer for the rest of the gesture even when the list
  cannot scroll further.

So "the list is at its end and the drag continues into the editor" has no path
to happen: reaching the end clamps the position (`ClampingScrollPhysics`), it
does not release the gesture.

## What was measured here

Driven through the real field (caret seeded, `popupController.show(...)`,
30-line fixture in a 200 px viewport so the editor's own scrollable really
overflows) — every combination of list length and gesture:

- Wheel over a long list (max scroll extent 189 px): the list scrolls, the
  editor stays at 0.
- Wheel again at the list's end: the list clamps, the editor stays at 0.
- Wheel over a short list (extent 0, nothing to scroll): the editor stays at 0.
- Finger drag on a long list, dragged well past its end and released: the list
  clamps and springs back, the editor stays at 0.
- Finger drag on a short list: nothing scrolls at all.
- Same five with the editor embedded in an outer `SingleChildScrollView` page
  (the realistic app shape): neither the editor nor the page moves.

`physics: const ClampingScrollPhysics()` is also exactly what upstream
`akvelon/flutter-code-editor` still ships (`lib/src/wip/autocomplete/popup.dart`
on `main`), so there is no upstream fix to port either.

## History

The 2022 recording predates upstream PR `akvelon/flutter-code-editor#209`,
which moved the popup out of the field's own `Stack` and into the root overlay
(the placement the sibling-branch argument above depends on). The recording-era
layout had the popup as the topmost `Stack` child, so it won hit-testing there
too; nothing in the current tree can produce the symptom.

## Delivered

- Regression pins in
  `test/src/code_field/suggestion_scroll_stays_in_popup_test.dart`: the wheel
  over a scrollable suggestion list still scrolls the list, and the editor's
  scroll position stays at 0 — the property the report claims is broken.
