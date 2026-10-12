# Plan: suggestion-popup-customization (#87)

Spec: `spec.md` · Research: `research.md` · Contract:
`contracts/suggestion-item-builder.md`

## Shape of the change

Three files, one new field, one dispatch.

### 1. `CodeField` gains the field

`lib/src/code_field/code_field.dart`, beside `autocompleteBackground`
(line 217):

```dart
/// Builds one row of the suggestion popup.
///
/// When null the popup renders its built-in row. When set, the popup calls it
/// once per suggestion with the suggestion's text, whether that row is the
/// selected one, and a callback that commits it — the same tap behaviour the
/// built-in row has, including returning focus to the editor.
final Widget Function(
  BuildContext context,
  String suggestion,
  bool isSelected,
  VoidCallback onSelect,
)? suggestionItemBuilder;
```

Constructor entry goes directly after `this.autocompleteBackground,` so the two
popup knobs sit together.

### 2. `Popup` gains the same field, and dispatches

`lib/src/wip/autocomplete/popup.dart`:

- the field, documented identically;
- `_buildListItem` (line 175) becomes:

```dart
Widget _buildListItem(int index) {
  final builder = widget.suggestionItemBuilder;
  if (builder != null) {
    return builder(
      context,
      widget.controller.suggestions[index],
      widget.controller.selectedIndex == index,
      _commitAt(index),
    );
  }
  // ...unchanged: Material > InkWell > ColoredBox > Padding > Text
}

/// What the built-in row does on tap, extractable so the builder's callback is
/// the same code rather than a second copy of it.
VoidCallback _commitAt(int index) => () {
      widget.controller.selectedIndex = index;
      widget.parentFocusNode.requestFocus();
      widget.controller.onCompletionSelected();
    };
```

`_commitAt` is lifted out of the existing `InkWell.onTap` (lines 179-183) so the
built-in row and the builder's callback run **one** implementation. Two copies
would be the obvious way for them to drift.

### 3. `CodeField` wires it through

`_buildSuggestionOverlay` (`code_field.dart:1042-1056`) already passes
`controller`, `normalOffset`, `flippedOffset`, `editingWindowSize`, `style` and
`backgroundColor`. One more line: `suggestionItemBuilder: widget.suggestionItemBuilder`.

## What is deliberately not touched

- `Popup`'s placement, clamp, flip and `_rowHeight`. Already correct (R1) and
  pinned (R2); the dispatch adds no layout node, so `popup_placement_test.dart`
  must pass untouched.
- The built-in row's own appearance and constructor.
- `PopupController`'s public surface — no narrowing of `shouldShow`,
  `enabled` or `suggestions`, and no new export from the barrel.
- `CodeController`'s structure. The coupling is documented, not restructured.

## Documentation of the coupling (T008)

On `CodeController.popupController` (line 128), a doc comment naming every call
site and the reason each exists, so the next reader does not have to grep for
them. The list is in `research.md` R4.

## Risks

- **`_commitAt` closure allocation per row per build.** `_buildListItem` is
  called per visible row on every popup rebuild; allocating a closure per row is
  what the built-in path does implicitly today via `onTap: () {...}`, so this
  is no worse. Not a new cost.
- **A builder that throws takes the popup down with it.** The same is true of
  any `itemBuilder` in Flutter (`ListView`, `DropdownMenu`). No guard; a
  throwing builder is a host bug and swallowing it would hide it.
- **`EXEMPT_LINES` renumbering.** The dispatch inserts lines in `popup.dart`
  above the built-in row. Check the gate's line-number pins before adding an
  exemption; `popup.dart` currently has none, so this is a check, not a fix.

## Tests

`test/src/wip/autocomplete/popup_item_builder_test.dart`, written first, eight
tests: the two default-path rows, the dispatch, `isSelected`, the commit path,
the `isSelected`-ignoring builder, and the two `PopupController` sequence pins.

The existing `popup_test.dart`, `popup_controller_test.dart` and
`popup_placement_test.dart` are the regression net and must pass unmodified.
