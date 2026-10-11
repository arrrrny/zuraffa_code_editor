# Cycle log: ios-horizontal-scroll-85

Project is not zuraffa-wired (`.zfa.json` absent) — LLM-guided loop per the
`/speckit-tdd-run` fallback. Baseline: master `89ff2c6`, branch
`bug/ios-horizontal-scroll-85`.

This cycle produced **no code change**. The reported symptom did not reproduce,
and the one real defect underneath it has no application-level fix. The cycle log
records the red measurements and the one wrong turn, both of which are the
deliverable.

## Red — measurement 1: the filed symptom does not reproduce

Example-02 widget tree, 390x844, 240 px leftward drag over the code text,
`_horizontalCodeScroll.position.pixels`:

```
defaultTargetPlatform=iOS     before=0.0  after=201.16666666666669
defaultTargetPlatform=android before=0.0  after=0.0
```

The platform claim is inverted. A control with no fork code (a plain `TextField`
in a horizontal `SingleChildScrollView`) gives the same split — iOS 270.0,
android 0.0.

## Red — measurement 2: mechanism attribution

Same drag, `debugDefaultTargetPlatformOverride` crossed against
`Theme(platform:)` to separate the recognizer from the scroll physics:

```
default=iOS      theme=android  after=201.16666666666669
default=android  theme=iOS      after=0.0
```

The outcome tracks `defaultTargetPlatform`, i.e. which recognizer `TextField`
registers and how `eagerVictoryOnDrag` is set
(`text_selection.dart:3731`), **not** `Theme.platform` or
`ScrollBehavior.getScrollPhysics`.

## Red — measurement 3: the wrong turn (kept so it is not repeated)

The first hypothesis was that nothing scrolls `_horizontalCodeScroll` except the
drag, and that the caret reveal was missing. Probed on an **unfocused** field:

```
PROBE5 before=0.0 max=446.0
PROBE5 after selection move=0.0        (selection collapsed at offset 100)
PROBE5 after End=0.0
PROBE5 after 40xRight=0.0  sel=...offset: 136...
```

That is a focus artifact, not a defect: `_scheduleShowCaret` is gated on focus, so
an unfocused field never reveals its caret. Four tests written against this
reading were red for the wrong reason. Re-probed with the field focused:

```
B3 setup        px=4740.0   caret at offset 300 (end of a 300-char line)
B3 after End    px=4740.0   caret at offset 300
B3 after Home   px=0.333    caret at offset 0
B3 after 30xRight px=285.33 caret at offset 30, past the right edge -> revealed
B3 after tap    px=285.33   caret placed by a tap, revealed
```

…and via the IME: `enterText` of 300 characters ends at
`px == maxScrollExtent`. The reveal already works on every platform.

## Green — the pins

The four false-red tests were rewritten against the focused measurements and
reduced to what the evidence actually supports: six pins in
`test/src/code_field/horizontal_scroll_behaviour_test.dart`, all green on the
unfixed tree:

- `the code area scrolls horizontally on drag / under an iOS platform override` —
  GREEN (pins 0 → >0).
- `... / an android platform override leaves the drag to text selection` — GREEN
  (pins 0, and documents why in the test body).
- `the caret is revealed horizontally / End, Home and the arrow keys move the code
  area` — GREEN (caret at end revealed; `Home` → ~0; `End` → revealed; 30x `→`
  past the right edge → revealed).
- `... / typing a long line ends with the caret in view` — GREEN.
- `... / content that fits the viewport` — GREEN (`maxScrollExtent == 0`).
- `... / wrap: true reflows instead of scrolling` — GREEN (no horizontal
  `Scrollable` at all).

No files under `lib/` were modified. Full suite, `dart analyze` and the coverage
gate are recorded in `test.md`.

## Deliberately not attempted

- A `HorizontalDragGestureRecognizer` deeper than the `TextField`'s, driving
  `_horizontalCodeScroll` by hand: it would win the arena, but it discards
  Flutter's scroll physics and ballistics for the whole code area and competes
  with a future `Scrollbar` thumb drag.
- `TextField.enableInteractiveSelection: false`: removes the drag recognizer, and
  with it every selection affordance.
- An interactive horizontal `Scrollbar`: the correct follow-up, but Material's
  `ScrollBehavior.getScrollbars` suppresses it on Android/iOS, so it needs a
  `showScrollbar`/platform decision of its own. Documented in `assessment.md`.
