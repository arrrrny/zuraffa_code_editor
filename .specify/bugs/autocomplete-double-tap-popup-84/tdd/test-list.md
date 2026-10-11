# Test list: autocomplete-double-tap-popup-84

Outer-loop behaviours, derived from `spec.md` (`outer-only` — the bug dir has
no `plan.md`). Each entry names the file it lives in and whether it is red on
master.

## From User Story 1 — a single tap commits (P1)

1. **a single tap commits the suggestion, hides the popup and returns focus to
   the editor** — US1.1, FR-001/003, SC-001.
   `test/src/code_field/tap_accepts_suggestion_test.dart` (driven through the
   real `CodeField` by `wt.tap`, the touch path) and
   `test/src/wip/autocomplete/popup_test.dart` (the row's own gesture).
   RED on master: `popup.dart:141-149` puts `onCompletionSelected()` on
   `onDoubleTap` only, so `controller.text` keeps the typed prefix.
2. **the commit is observable without waiting for the double-tap timeout** —
   US1.2, FR-002, SC-002. Same file: the tap is followed by a 100 ms pump, far
   under `kDoubleTapTimeout`. RED on master (nothing to observe).
3. **the tapped row is the one committed, not the default selection** —
   US1.1. `popup_test.dart`: tap the third row, assert `selectedIndex == 2` and
   exactly one commit. Replaces the old double-tap test.
4. **Enter still commits, and arrows + Enter commits the moved-to row** —
   US1.3, US3.1, SC-005. `tap_accepts_suggestion_test.dart`. Guard: green on
   master, must stay green — the tap change must not trade a touch regression
   for a keyboard one.

## From User Story 2 — the popup stays inside the window (P1)

5. **a caret past the popup's width keeps the popup inside the window
   horizontally** — US2.1, FR-004/006, SC-003.
   `test/src/wip/autocomplete/popup_placement_test.dart` (a 390 px editor in an
   800 px window, caret x past the clamp) and
   `tap_accepts_suggestion_test.dart` (a 360 px phone window through the field).
   RED on master: `popup.dart:65-70` computes `left =
   editingWindowSize.width - 300 + editorOffset.dx - 100`, which is negative
   for every phone-sized editor (360 - 390 → -32).
6. **a caret near the window's bottom flips the popup on the height the rows
   actually need** — US2.2, FR-005, SC-004. `popup_placement_test.dart`, with
   an editor shorter than the popup's max height (the case
   `popup.dart:118-128` refuses outright: `100 < editingWindowSize.height` is
   false). RED on master: the popup runs past the bottom edge.
7. **room below → no flip** — US2.2, FR-005. Same file, one suggestion and a
   caret with room below: `normalOffset.dy + neededHeight < windowHeight`.
   RED on master: the constant 100 forces a flip that the rows do not need.
8. **the popup is placed against the window, not the editor's render box** —
   US2.3, FR-006. Same file: a small editor inset in a large window. RED on
   master: every bound in `popup.dart` is the editor box, so a popup that fits
   the window is rejected (or placed off-edge) by the editor's smaller width.
   Also pins the field side: `code_field.dart:362/:429` filled `windowSize`
   from the field's own render box, so the popup's "window" was the editor.
9. **the popup is bounded by the window it is given** — US2.3, FR-006. Same
   file: the window the field hands over is the only bound, including a window
   narrower than the popup's max width (the clamp must not go negative) and an
   empty suggestion list (the height arithmetic must not index it). Red entries
   in this group are the phone-narrow and inset cases; the rest are guards on
   the new contract.

## Guards (green on master, must stay green)

10. **the package's public surface is unchanged** — FR-007.
    `lib/zuraffa_code_editor.dart` still does not export `src/wip/`
    (compile-time: the tests import `src/wip/autocomplete/popup.dart` by path,
    as they already do).

## Notes

- The master test `popup_test.dart` 'a tap on an item selects it and returns
  focus to the editor' **pins the bug**: it asserts `completions` is empty
  after a single tap with the reason 'a single tap only moves the selection,
  it does not commit'. Entry 1 rewrites it; the assertion is inverted, not
  deleted.
- The bare popup renders as a fixed 300x100 box with 20 px rows (measured),
  so a needed height is `min(count * 20, 100)` for the default style.
- The popup's bound is the window it is *given*: `CodeField` fills
  `editingWindowSize` from `MediaQuery` (the real window) rather than its own
  render box, so the popup level needs no `MediaQuery` of its own and the
  spec's "MediaQuery unavailable" edge case no longer applies — see the
  deviation note in `cycle-log.md`.
- `lib/src/wip/` is inside the coverage gate (only `popup.dart:76`'s dead
  `ItemScrollController` attach is exempted), so every new line there must be
  covered by these tests — including the empty-list and capped-height branches.
