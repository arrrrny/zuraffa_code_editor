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
