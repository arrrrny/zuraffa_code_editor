# Contract: `CodeField.suggestionItemBuilder`

Fork issue #87 · upstream `akvelon/flutter-code-editor#211`
Spec: `.specify/specs/suggestion-popup-customization-87`

## The hook

Added to `CodeField` (`lib/src/code_field/code_field.dart`), beside the
existing `autocompleteBackground`:

```dart
final Widget Function(
  BuildContext context,
  String suggestion,
  bool isSelected,
  VoidCallback onSelect,
)? suggestionItemBuilder;
```

Nullable, defaults to `null`, no `const` class initializer requirement beyond
the field's own default.

## What the popup does with it

`Popup._buildListItem(int index)` (`lib/src/wip/autocomplete/popup.dart:175`)
becomes a dispatch:

```dart
Widget _buildListItem(int index) {
  final builder = widget.suggestionItemBuilder;
  if (builder != null) {
    return builder(
      context,
      widget.controller.suggestions[index],
      widget.controller.selectedIndex == index,
      widget.onSelectAt(index),
    );
  }
  // ...the existing Material > InkWell > ColoredBox > Padding > Text chain
}
```

`Popup` therefore gains one field, `suggestionItemBuilder`, which
`CodeField._buildSuggestionOverlay` (`code_field.dart:1042`) fills from
`widget.suggestionItemBuilder` — the same place it already passes
`style: textStyle` and `backgroundColor: _popupBackground`.

## The commit path

`onSelect` must do exactly what the built-in row does on tap
(`popup.dart:179-183`):

```dart
controller.selectedIndex = index;
parentFocusNode.requestFocus();
controller.onCompletionSelected();
```

It is passed to the builder rather than reached for because the focus return
is the half a host would otherwise drop, and dropping it leaves the editor
unfocused after a completion is chosen.

## Why the text is an argument

`PopupController` is not exported from `lib/zuraffa_code_editor.dart`, so a
builder invoked from outside the package cannot read
`controller.suggestions[index]`. Passing the text keeps the hook usable
without exporting a `wip` type. `isSelected` is passed for the same reason — a
host that paints its own selected state does not need the controller to know
which row is selected.

## What a host row is wrapped in

The builder's widget is returned inside a `Material(type:
MaterialType.transparency)`. Two reasons, both found in review of #140 rather
than in the original spec:

1. **It is the one thing the built-in row gives a host for free.** A `ListTile`
   — the builder a host is most likely to reach for — needs a `Material`
   ancestor, and without the wrapper the popup hands it the surrounding app's
   or asserts. The doc example advertised a shape that would have crashed a host
   in debug.
2. **It keeps the row's own height the height the flip was measured at.** Every
   row's `Text` renders one level below a `Material`, which is what installs the
   ambient `bodyMedium` `DefaultTextStyle` `_rowHeight` measures against. A
   `MaterialType.transparency` box paints nothing, so the host's own surface —
   or the popup's `backgroundColor` — shows through unchanged.

The row height itself is **not** customizable, and this is now documented on
both widgets: the popup measures each suggestion as the built-in row's single
line and decides the flip and the clamp on that. A builder returning a taller
row is laid out at its own height, so a list of them can be taller than the
space the flip reserved. A host that needs taller rows has to accept that.

## Default behaviour

With the field `null` the popup runs the built-in row, widget for widget, with
the same arguments. No `Stack`, no conditional wrapper, no extra layout node:
the branch is inside `_buildListItem`, so the default tree is identical to
before this change and nothing about placement is touched.

## Tests the contract implies

| # | Test | Pins |
| - | ---- | ---- |
| 1 | no builder → built-in row, widget for widget | default tree |
| 2 | builder set → called once per suggestion with the text | dispatch |
| 3 | `isSelected` follows `selectedIndex` | selection state |
| 4 | `onSelect` commits the right suggestion and returns focus | commit path |
| 5 | a builder ignoring `isSelected` still commits correctly | contract |
| 6 | the documented `show`/`hide` sequence on `PopupController` | coupling pin |
| 7 | a host row gets a `Material` ancestor of its own | the wrapper above |
