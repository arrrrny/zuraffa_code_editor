# Cycle log: autocomplete-popup-transparency

## Red

`test/src/code_field/autocomplete_popup_background_test.dart` written against
master `0d57280`, with the `autocompleteBackground` cases removed so the file
compiled:

```
Expected: not null
  Actual: <null>
```

Test 1 alone — exactly the symptom the issue reports. Tests 2 and 3 were
added in a second cycle.

## Green

Fix: `_CodeFieldState` resolves a `_popupBackground` once per build as
`widget.autocompleteBackground ?? _backgroundCol ?? themeData.cardColor`,
and `_buildSuggestionOverlay` passes it to `Popup` instead of
`_backgroundCol`. `_backgroundCol` keeps its existing meaning (the editor's
own background, nulled by `decoration`) so the root `Container` is untouched.

Result: `flutter test test/src/code_field/autocomplete_popup_background_test.dart`
— 3/3 green. Full suite 495/495 green; analyze and format clean.

## Red–green (knob)

The `autocompleteBackground` knob test failed as a compile error
(`No named parameter with the name 'autocompleteBackground'`); after adding
the field and its resolution it went green, and was re-verified to fail with
`Actual: Color(0x21212121)` (the theme's card colour) when the precedence is
removed.

## Refactor

- The `?? themeData.scaffoldBackgroundColor` tail was dropped: `cardColor`
  is non-nullable, so the analyzer flagged the tail as dead code.
- `!.opacity` → `!.a` in the test (deprecated member).
- The knob is named `autocompleteBackground` to parallel the existing
  `background`/`decoration` pair while naming which surface it styles.
