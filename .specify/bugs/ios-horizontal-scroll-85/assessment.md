# Bug Assessment: Horizontal scrolling does not work on iOS

- **Slug**: ios-horizontal-scroll-85
- **Created**: 2026-10-11
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/85
  (upstream akvelon/flutter-code-editor#280)
- **Verdict**: **not reproducible as filed — the reported platform split is
  inverted.** The one real defect underneath it is platform-general and
  quantified below; it has no application-level fix, so this issue is closed
  with a pin and a documented follow-up.
- **Severity**: high

## Symptom as filed

"`CodeField` does not scroll horizontally on iOS. Check your example 02, you can
scroll vertically but not horizontally. Works fine on Android though."

## Reproduction

Example 02 (`example/lib/02.code_field/main.dart`) — `MaterialApp` → `Scaffold`
→ `SingleChildScrollView` → `CodeField(controller: CodeController(text:
javaFactorialSnippet, language: java))`.

The longest line is `System.out.println("Factorial of " + num + " is " +
factorial(5));` — 70 characters, so the code area has a real horizontal extent on
a phone viewport. The widget tree the drag lands on
(`lib/src/code_field/code_field.dart:471-526`, `_wrapInScrollView`):

```
SingleChildScrollView(scrollDirection: Axis.horizontal,
                      controller: _horizontalCodeScroll)
  └ IntrinsicWidth
      └ Column(mainAxisSize: min, crossAxisAlignment: stretch)
          ├ ConstrainedBox(maxHeight: 0, minWidth: constraints.maxWidth)
          │    └ Padding(right: 16) → Text(longestLine)   // invisible width pin
          └ ConstrainedBox(maxHeight: maxHeight)
               └ TextField(maxLines: null, scrollController: _codeScroll)
```

`IntrinsicWidth` gives the column a *tight* width equal to the longest line's
intrinsic width, so the `TextField`'s render box is stretched to the whole
document width (measured: `Size(1158.0, 440.0)` inside a `302.0` px viewport,
`maxScrollExtent == 856.0`).

## What was measured

Every measurement below is a widget test driving the exact example-02 widget
tree, with the probes deleted afterwards. `_horizontalCodeScroll.position.pixels`
is read before and after a 240 px leftward drag over the code text.

### 1. The drag: iOS works, android does not — the inverse of the report

| `defaultTargetPlatform` | pixels before | pixels after |
|---|---|---|
| iOS | 0.0 | **201.17** |
| android | 0.0 | **0.0** |

A control with no fork code involved — a plain `TextField` inside a horizontal
`SingleChildScrollView` — shows the same split (iOS 270.0, android 0.0), so this
is not something the package does.

### 2. The caret reveal already works, on every platform

With the field focused (as a real user's is), moving the caret to the end and back
reveals it horizontally, with `maxScrollExtent == 446`:

```
setup        px=4740.0   caret at offset 300 (end of a 300-char line)
after End    px=4740.0   caret at offset 300
after Home   px=0.333    caret at offset 0
30× arrow→   px=285.33   caret at offset 30, past the right edge → revealed
```

Plus IME entry: `enterText` of 300 characters ends at `px == maxScrollExtent`.
`TextField`'s `RenderEditable.showOnScreen` already drives the reveal; the
vertical counterpart is handled by the same mechanism, which is why the reporter
sees "vertical works".

The first measurement attempt reported this as broken; that was wrong and is
recorded here so it is not repeated: `_scheduleShowCaret` is gated on focus, so an
unfocused field never reveals its caret. Unfocused is the wrong probe for a
keyboard/IME behaviour.

## Root cause (the one real defect)

The code area's horizontal scroll view is an *ancestor* of the `TextField`, so the
drag that would scroll it lands on the `TextField`'s own recognizers first.
`TextField` → `EditableText` → `TextFieldSelectionGestureDetectorBuilder.buildGestureDetector`
(`packages/flutter/lib/src/widgets/text_selection.dart:3684`) registers a
**platform-specific** drag recognizer for text selection
(`text_selection.dart:3712-3748`):

- Apple and Android: `TapAndHorizontalDragGestureRecognizer`, configured
  `..eagerVictoryOnDrag = defaultTargetPlatform != TargetPlatform.iOS`
  (`text_selection.dart:3731`)
- Linux / macOS / Windows: `TapAndPanGestureRecognizer`, whose
  `eagerVictoryOnDrag` defaults to `true`

Hit-test order is deepest-first, so the `TextField`'s recognizer enters the
gesture arena **before** the scroll view's `HorizontalDragGestureRecognizer`.
`BaseTapAndDragGestureRecognizer` documents the consequence
(`tap_and_drag.dart:659-672`) and implements it at
`tap_and_drag.dart:1206-1210`: when `eagerVictoryOnDrag` is true it
`resolve(GestureDisposition.accepted)` on drag start, the arena sweep rejects the
scroll view's drag, and the drag becomes a text selection. With the flag false
(iOS) the recognizer instead waits for the arena to resolve
(`tap_and_drag.dart:1017-1022`), so the scroll view's recognizer wins and the drag
scrolls.

**Mechanism attribution** — the same drag with `debugDefaultTargetPlatformOverride`
and `Theme(platform:)` crossed:

| default | theme | pixels after |
|---|---|---|
| iOS | android | 201.17 |
| android | iOS | 0.0 |

The outcome tracks `defaultTargetPlatform` — which recognizer `TextField`
registers and how `eagerVictoryOnDrag` is set — and **not** `Theme.platform` or
`ScrollBehavior.getScrollPhysics`. So the difference is not scroll physics
(`BouncingScrollPhysics` vs `ClampingScrollPhysics`), and not anything this
package does.

`EditableText`'s internal `Scrollable` is vertical for multiline input
(`editable_text.dart:5916`: `axisDirection: _isMultiline ? AxisDirection.down :
AxisDirection.right`), and the code field is multiline, so the horizontal scroll
*must* be the outer scroll view. There is no other place to put it.

## Why there is no fix in this package

- The recognizer is built inside Flutter's `TextSelectionGestureDetector`;
  `TextField`/`EditableText` expose no priority knob, no scroll-view integration,
  and no way to override which recognizer is registered.
- The only application-level lever is `TextField.enableInteractiveSelection:
  false`, which removes the drag recognizer entirely — and with it every text
  selection affordance on the code (tap-to-place, double/triple-tap word and line
  selection, long-press selection and handles). Not an acceptable trade for a code
  editor.
- Replacing the ancestor `SingleChildScrollView` with a hand-rolled
  `HorizontalDragGestureRecognizer` deeper in the tree would beat the recognizer,
  but it would discard Flutter's scroll physics and ballistics for the whole code
  area and compete with the `Scrollbar` thumb drag. Better not done than done
  badly.

So: iOS already scrolls on drag and every platform already reveals the caret.
What genuinely does not work on non-Apple platforms is *drag the code text to
scroll*, and the way to reach the right edge there is a drag affordance that is
not the text itself — see the follow-up.

## Proposed remediation

Ship no behaviour change. Pin what is measured so it cannot regress silently:

- `test/src/code_field/horizontal_scroll_behaviour_test.dart` — a drag over the
  code text scrolls `_horizontalCodeScroll` under an iOS platform override, and
  does not under an android one; the caret reveal via `End`/`Home`/`→` works;
  `wrap: true` and content that fits the viewport leave the position alone.
- Acceptance criteria 1, 2 and 4 of the issue ("reaches content past the right
  edge on iOS", "not platform-gated", "example 02 scrolls horizontally on iOS")
  are already satisfied; criterion 3 ("a test pins the scroll offsets/geometry")
  is what this PR delivers.

## Follow-up (deliberately not in this PR)

An interactive horizontal `Scrollbar` on the code area. `Scrollbar`'s thumb drag
uses its own `HorizontalDragGestureRecognizer`, which sits deeper than the
`TextField`'s and therefore wins the same arena — so a thumb drag would reach the
right edge on every platform without touching the gesture arena or removing
selection. Material's `ScrollBehavior.getScrollbars` suppresses the scrollbar on
Android/iOS, so shipping it means either `showScrollbar: true` (a UI change on
mobile) or a platform check, both of which deserve their own issue.

## Risks & Considerations

- The pin asserts current platform behaviour. If Flutter ever changes
  `eagerVictoryOnDrag`, the android case turns green and the pin needs updating —
  that is the intended signal, not a broken test.
- The pin must not depend on focus (see the wrong measurement above) except where
  it is explicitly testing a caret reveal, which requires it.
