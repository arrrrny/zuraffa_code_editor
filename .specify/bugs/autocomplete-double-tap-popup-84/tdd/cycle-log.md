# Cycle log: autocomplete-double-tap-popup-84

## Baseline

Branch `bug/autocomplete-double-tap-popup-84` @ `524065d`, master @ `a02539a`.
Geometry measured on master before writing anything (probe, deleted):

- the bare `Popup` renders as a fixed 300x100 box, rows 20 px each;
- the field auto-scrolls a full line's caret to a window-relative offset, so on
  master a 300 px window with a 40-char line put the popup at `left = -12`
  (300 - 300 + editorOffset.dx - 100) and a 390 px window at `left = 78`.

## Red

`tdd/test-list.md` entries written against master, then run:

```
popup_test.dart: a tap on an item commits it and returns focus to the editor
  Expected: <1>   Actual: <0>          # the commit hung off onDoubleTap
popup_placement_test.dart: a caret past the popup width ...
  Expected: <150>  Actual: <-10.0>     # 390 - 300 - 100
popup_placement_test.dart: a small editor inset in the window ...
  Expected: <250>  Actual: <-100.0>    # 200 - 300 + 100 - 100
popup_placement_test.dart: a caret near the bottom of a short editor ...
  Expected: <442>  Actual: <572.0>     # flip refused: 100 < editingWindowSize.height
popup_placement_test.dart: room below keeps the popup below the caret
  Expected: <560>  Actual: <430.0>     # the constant 100 forced a flip one row does not need
tap_accepts_suggestion_test.dart: and hides the popup
  Expected: 'beta '  Actual: 'al'
tap_accepts_suggestion_test.dart: on a window too narrow for it
  Expected: a value greater than or equal to <0>   Actual: <-11.5>
tap_accepts_suggestion_test.dart: above a caret near the bottom of a short editor
  Expected: a value less than <500>   Actual: <560.0>
```

The arrows + Enter guard and the room-below guard were green on master, as the
test list predicts. One test passed vacuously on the first attempt — the
selection was seeded before the field was pumped, so `_updatePopupOffset` never
ran and the popup sat at its default offset. Re-ordering the pump turned it red
for the intended reason.

## Green

Fix:

- `lib/src/wip/autocomplete/popup.dart` — `onTap` commits (the `onDoubleTap`
  handler is gone, so the gesture arena no longer holds the first tap back);
  placement is now measured against the window the widget is given (`windowSize`,
  which `CodeField` fills from `MediaQuery`): `left` and `top` are clamped into
  it — the unflipped top against the height the rows need, the flipped one
  against the popup's maximum height — and the flip compares that needed height
  against the window instead of the constant 100 against the editor's own
  height. The unexplained `-100` and its `TODO(nausharipov)` are gone, and so is
  the now-unused `editorOffset` parameter.
- `lib/src/code_field/code_field.dart` — the popup's `windowSize` is the
  window (`MediaQuery`), not the field's own render box, in both the `initState`
  and `rebuild` post-frame callbacks.

Result: the three files, 16/16 green. Full suite 744/744 green (was 734).
`dart analyze` on the changed files reports only the pre-existing
`withOpacity` deprecation infos from master's row code; `dart format` clean.

## Deviation from the spec's edge cases

The spec's "MediaQuery unavailable in a bare Popup pumped test" edge case became
moot: `flutter_test`'s binding injects a root `MediaQuery`, so
`MediaQuery.maybeOf` never returns null inside a pump, and the popup reads no
`MediaQuery` at all now — the field resolves the window and hands it over. The
branch is unreachable, which would have cost the coverage gate; the popup's
`editingWindowSize` doc comment records the new contract instead.
