# Test list: gutter-error-popup-decoration

Fork issue: #82 · Spec: `.specify/specs/gutter-error-popup-decoration/spec.md`

Every test starts red. The order below is the red → green order.

## New file: `test/src/gutter/error_popup_decoration_test.dart`

Shared harness, copied in shape from `error_popup_content_test.dart`: mount a
`GutterErrorWidget` with a mouse pointer, enter to open the overlay, and read the
`Container`'s decoration out of the overlay entry.

### The default is unchanged

1. With no decoration supplied, the popup container's decoration is a
   `BoxDecoration` whose `color` is the popup text style's `backgroundColor`.
2. With no decoration supplied and a popup text style whose `color` is set, the
   decoration's border is `Border.all` in that colour.
3. With no decoration supplied and a popup text style whose `color` is null, the
   decoration has **no** border — the existing `null` branch.

### The override at the widget level

4. `GutterErrorWidget.popupDecoration` supplies the container's decoration.
5. The override does not disturb the popup's content: message, url, suggestion
   and the divider are still all found.

### The override at the style level

6. `GutterStyle.errorPopupDecoration` is carried into the gutter's popups.
7. `GutterStyle.copyWith` keeps `errorPopupDecoration` when it is given none, and
   replaces it when it is given one.
8. Two issues on different lines under one style share the same decoration (the
   decoration is a style-level default, unlike the icon which is per issue).

## Existing tests that must stay green unchanged

- `test/src/gutter/error_popup_content_test.dart` — asserts on the popup's text
  and divider, not its chrome.
- `test/src/gutter/error_popup_dispose_test.dart` — mounts
  `GutterErrorWidget` positionally.
- `test/src/gutter/gutter_folding_test.dart` — asserts on
  `findsOneWidget`/`findsNothing` for `GutterErrorWidget`.
- `test/src/gutter/error_icon_override_test.dart` — asserts the per-issue
  `GutterErrorWidget.icon` resolution (#81).

## CHANGELOG

`Unreleased › Added`: `GutterStyle.errorPopupDecoration` and
`GutterErrorWidget.popupDecoration` (#82).
