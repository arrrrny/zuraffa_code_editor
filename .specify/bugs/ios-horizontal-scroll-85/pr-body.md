# Horizontal scrolling does not work on iOS (#85)

Closes #85 (upstream `akvelon/flutter-code-editor#280`).

**This PR changes nothing in `lib/`.** It ships the tests that pin what was
measured, because the reported symptom does not reproduce as filed and the one
real defect underneath it has no application-level fix. The evidence is below and
in `.specify/bugs/ios-horizontal-scroll-85/assessment.md`.

## The report

> `CodeField` does not scroll horizontally on iOS. Check your example 02, you can
> scroll vertically but not horizontally. Works fine on Android though.

## What was measured

Every number is a widget test driving the exact example-02 widget tree
(`MaterialApp` → `Scaffold` → `SingleChildScrollView` → `CodeField`), reading
`_horizontalCodeScroll.position.pixels` before and after a 240 px leftward drag
over the code text. The probes were deleted; the numbers are transcribed in
`tdd/cycle-log.md`.

**1. The drag works on iOS and does not on Android — the inverse of the report.**

| `defaultTargetPlatform` | before | after |
|---|---|---|
| iOS | 0.0 | **201.17** |
| android | 0.0 | **0.0** |

A control with no fork code involved — a plain `TextField` inside a horizontal
`SingleChildScrollView` — gives the same split (iOS 270.0, android 0.0), so this
is not something the package does.

**2. The caret reveal already works, on every platform.**

With the field focused, `maxScrollExtent == 446`:

```
setup          px=4740.0   caret at offset 300 (end of a 300-char line)
after End      px=4740.0
after Home     px=0.333    caret at offset 0
after 30x →    px=285.33   caret at offset 30, past the right edge → revealed
after tap      px=285.33   caret placed by a tap → revealed
```

IME entry too: `enterText` of 300 characters ends at `px == maxScrollExtent`.
`TextField`'s `RenderEditable.showOnScreen` drives the reveal — the same mechanism
that handles the vertical follow, which is why the reporter sees vertical working.

**3. Mechanism attribution: it is the recognizer, not the scroll physics.**

The same drag with `debugDefaultTargetPlatformOverride` crossed against
`Theme(platform:)`:

| default | theme | after |
|---|---|---|
| iOS | android | 201.17 |
| android | iOS | 0.0 |

The outcome tracks `defaultTargetPlatform` and therefore
`packages/flutter/lib/src/widgets/text_selection.dart:3731`:

```dart
..eagerVictoryOnDrag = defaultTargetPlatform != TargetPlatform.iOS
```

`TextField`'s `TextSelectionGestureDetector` registers a
`TapAndHorizontalDragGestureRecognizer` for text selection. It is deeper in the
hit-test tree than the code area's `SingleChildScrollView`, so it enters the
gesture arena first; where `eagerVictoryOnDrag` is true it
`resolve(GestureDisposition.accepted)` on drag start
(`tap_and_drag.dart:1206-1210`), the sweep rejects the scroll view's drag, and the
drag becomes a text selection. Where it is false (iOS) the recognizer waits for
the arena to resolve instead (`tap_and_drag.dart:1017-1022`), so the scroll view
wins and the drag scrolls. `BouncingScrollPhysics` vs `ClampingScrollPhysics` is
not involved.

## Why there is no fix here

- The recognizer is built inside Flutter's `TextSelectionGestureDetector`.
  `TextField`/`EditableText` expose no priority knob and no way to override which
  recognizer is registered.
- The only application-level lever is `TextField.enableInteractiveSelection:
  false`, which removes the drag recognizer and with it every selection affordance
  on the code (tap-to-place, double/triple-tap word and line selection, long-press
  selection and handles). Not an acceptable trade for a code editor.
- A hand-rolled `HorizontalDragGestureRecognizer` deeper in the tree would win the
  arena, but discards Flutter's scroll physics and ballistics for the whole code
  area and competes with a future `Scrollbar` thumb drag.

The horizontal scroll *must* be an ancestor `SingleChildScrollView`:
`EditableText`'s internal `Scrollable` is vertical for multiline input
(`editable_text.dart:5916`), and the code field is multiline.

## What this PR does ship

`test/src/code_field/horizontal_scroll_behaviour_test.dart` — six pins, all green
on an unmodified `lib/`:

| Pin | Protects |
|-----|----------|
| drag under an iOS platform override scrolls the code area | acceptance criteria 1 and 4 of the issue |
| the same drag under an android platform override does not | the Flutter platform split is visible in the suite instead of implied, so a Flutter upgrade that flips `eagerVictoryOnDrag` fails on purpose |
| `End`/`Home`/`→` reveal the caret horizontally | acceptance criterion 2 — the reveal is platform-independent |
| typing a long line ends with the caret revealed | the IME path |
| content that fits the viewport is not scrolled | no spurious scroll on short documents |
| `wrap: true` has no horizontal scroll view at all | the wrapped/unwrapped split in `_wrapInScrollView` |

## Verification

- Full suite: **737 passed** (`flutter test`) — the six new pins green on an
  unmodified `lib/`.
- `dart analyze` on the changed files: no issues.
- `dart format`: clean.
- Coverage gate: **100.00% (3360/3360 lines over 105 files)** — the change is
  test-only, so it adds no production lines.

## A wrong turn, recorded deliberately

My first measurement read "nothing scrolls `_horizontalCodeScroll` except the
drag, and the caret reveal is missing". That was a focus artifact:
`_scheduleShowCaret` is gated on focus, so an unfocused field never reveals its
caret. Four tests written against that reading were red for the wrong reason.
The wrong numbers are kept in `tdd/cycle-log.md` so the trap is not re-entered.

## Follow-up (out of scope)

An interactive horizontal `Scrollbar` on the code area is the right way to reach
the right edge on the platforms where dragging the code text selects instead of
scrolling: the thumb drag uses its own `HorizontalDragGestureRecognizer`, deeper
than the `TextField`'s, so it wins the same arena without touching selection.
Material's `ScrollBehavior.getScrollbars` suppresses scrollbars on Android/iOS,
so it needs a `showScrollbar: true` decision of its own — its own issue.
