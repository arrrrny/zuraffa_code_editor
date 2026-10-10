# Spec: gutter-error-popup-decoration

Fork issue: #82 · Upstream: akvelon/flutter-code-editor#217
Label: `spec` · Severity: `medium` · Backlog rank: 2

## What was asked

"Please allow me to override the gutter error popup decoration. Currently, it's
hardcoded in `lib/src/gutter/error.dart` … it would be better to provide a
`shape` and/or `borderSide` using the `GutterStyle`. Providing a `popupBuilder`
would be an alternative."

## What exists today

`_GutterErrorWidgetState._getErrorPopup()` builds the popup container's
decoration inline, deriving it from the popup text style:

```dart
decoration: BoxDecoration(
  color: style.backgroundColor,
  border: style.color != null ? Border.all(color: style.color!) : null,
),
```

where `style` is the `popupTextStyle` the widget was given. The host controls the
popup's colours only indirectly, by choosing a `TextStyle` whose
`backgroundColor` and `color` happen to be read here — which also means those two
`TextStyle` fields are load-bearing for something that is not text styling.

## What this spec adds

A `BoxDecoration?` escape hatch at the same two levels as the icon override in
#81:

1. **`GutterStyle.errorPopupDecoration`** — the decoration the gutter's popups
   use. Null keeps the derivation above, so a style that sets nothing renders
   exactly as before.
2. **`GutterErrorWidget.popupDecoration`** — for a host that mounts the widget
   directly, mirroring `GutterErrorWidget.icon`.

## Decisions

- **`BoxDecoration`, not `shape` + `borderSide`.** The ask names the two fields,
  but a `BoxDecoration` carries both (plus `borderRadius`, `boxShadow`,
  `gradient`) and is the type the code already builds. Two narrower fields would
  have to be merged back into one anyway.
- **The default does not change.** Null falls through to the existing derivation,
  byte for byte.
- **Not a `popupBuilder`.** That would replace the whole overlay, including the
  message text, the url link and the suggestion divider, and it would need a
  public `OverlayEntry` contract. It is a larger API than the ask justifies and
  the reporter offered it only as an alternative. Recorded as out of scope.
- **`copyWith` is extended**, matching #81.

## Out of scope

- `GutterStyle.errorPopupBuilder` (the reporter's alternative) — replacing the
  whole overlay rather than its chrome.
- Moving the derivation off the `TextStyle`'s background/color fields. That is a
  real smell, but changing it would alter every existing popup's appearance.

## Note for whoever edits `error.dart` next

`tool/coverage_gate.py` pins `EXEMPT_LINES` by **line number**. The two exempted
lines in the gutter files have been renumbered by every change around them and
already read `error.dart:98` and `gutter.dart:230` once #81's icon override is
applied underneath this one (#81 alone moved them to 89 and 229; this change then
moved `error.dart`'s to 98 and shifted the gate's bookkeeping for `gutter.dart`
to 230). The tool's "stale line exemption" line, or a bare coverage miss in one
of these two files, is the signal. Renumbering is not optional: the exemption is
what proves the branch dead, so losing it silently re-adds an uncovered line and
reds the gate.

Where they sit, so the next renumber is arithmetic rather than archaeology:
`error.dart`'s exempted line is the `return OverlayEntry(builder: (context) => Container())`
inside the `if (renderBox == null)` guard of `_getErrorPopup()`, and
`gutter.dart`'s is the `onTap: isFolded` argument of the first `_fillFoldThoggles`
loop. Grep for those two constructs and count — do not guess from a previous
value.

## Acceptance criteria

- [ ] `GutterStyle` accepts a nullable `errorPopupDecoration`.
- [ ] `GutterErrorWidget` accepts a nullable `popupDecoration`.
- [ ] A style that supplies neither renders the decoration derived from
      `errorPopupTextStyle`, exactly as today.
- [ ] A style that supplies one has that decoration used for the popup.
- [ ] `GutterStyle.copyWith` carries the field.
- [ ] The popup's content (message, url, suggestion, divider) is unaffected.
- [ ] Coverage stays at the 100% gate.

## Gates

`flutter test` · `dart analyze --fatal-infos` ·
`dart format --output=none --set-exit-if-changed .` ·
`python3 tool/coverage_gate.py --min 100`
